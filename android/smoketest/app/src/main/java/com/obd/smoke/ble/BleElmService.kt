
package com.obd.smoke.ble
import android.bluetooth.*
import kotlinx.coroutines.sync.Mutex
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import java.util.*
data class ElmResponse(val raw: String) {
  val ok: Boolean get() = raw.contains(">")
  fun cleanLines(): List<String> = raw.replace("\r"," ").replace("\n"," ").replace("\u0000","")
    .split(">")[0].replace("  "," ").trim().split("\r","\n","  ").map{ it.trim() }
    .filter{ it.isNotEmpty() && it != "?" && it != "NO DATA" && !it.startsWith("STOP") }
}
interface ElmTransport { suspend fun command(cmd: String): ElmResponse }
class BleElmService : android.app.Service(), ElmTransport {
  companion object { const val SERVICE_UUID="e7810a71-73ae-499d-8c15-faa9aef0c3f2"; const val CHAR_UUID="bef8d6c9-9c21-4c9e-b632-bd58c1009f9f"; @Volatile var instance: BleElmService?=null }
  private val scope = CoroutineScope(SupervisorJob()+Dispatchers.IO)
  private var gatt: BluetoothGatt?=null
  private var writeChar: BluetoothGattCharacteristic?=null
  private val buf = StringBuilder(); private val rxChan = Channel<String>(Channel.UNLIMITED)
  private val writeMutex = Mutex(); private var preferred: BluetoothDevice?=null
  val elm: ElmTransport get() = this
  override fun onBind(i: android.content.Intent?) = null
  override fun onCreate() { super.onCreate(); instance=this
    startForeground(1, android.app.Notification.Builder(this, chan()).setContentTitle("OBD BLE").setContentText("Active").setSmallIcon(android.R.drawable.stat_sys_data_bluetooth).build()) }
  override fun onDestroy() { super.onDestroy(); instance=null; gatt?.close(); scope.cancel() }
  private fun chan(): String { val id="obdsmoke"; if (Build.VERSION.SDK_INT>=26){ val nm=getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager; nm.createNotificationChannel(android.app.NotificationChannel(id,"OBD BLE", android.app.NotificationManager.IMPORTANCE_LOW))}; return id }
  fun scan(ctx: Context, cb:(List<String>)->Unit) {
    val bt=BluetoothAdapter.getDefaultAdapter()?:return; val scanner=bt.bluetoothLeScanner?:return
    val found=Collections.synchronizedMap(mutableMapOf<String,String>())
    val callback=object: ScanCallback(){ override fun onScanResult(t:Int,r:ScanResult){ val d=r.device; val name=d.name?:"Unknown"; found["$name (${d.address})"]=d.address; cb(found.keys.toList()) } }
    scanner.startScan(null, ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), callback)
    scope.launch { delay(6000); scanner.stopScan(callback); cb(found.keys.toList()) }
  }
  fun pickDevice(sel:String){ val bt=BluetoothAdapter.getDefaultAdapter()?:return; preferred=bt.bondedDevices.firstOrNull{ it.address==sel || (it.name?.let{ sel.startsWith(it)}?:false)} }
  fun connectPreferred(ctx: Context){ val bt=BluetoothAdapter.getDefaultAdapter()?:return; val dev=preferred?:bt.bondedDevices.firstOrNull(); dev?.connectGatt(this,false,gattCb,BluetoothDevice.TRANSPORT_LE) }
  private val gattCb=object: BluetoothGattCallback(){
    override fun onConnectionStateChange(g: BluetoothGatt, s:Int, st:Int){ if (st==BluetoothProfile.STATE_CONNECTED){ gatt=g; g.discoverServices() } }
    override fun onServicesDiscovered(g: BluetoothGatt, s:Int){ val svc=g.getService(UUID.fromString(SERVICE_UUID)); val ch=svc?.getCharacteristic(UUID.fromString(CHAR_UUID))
      if (svc!=null && ch!=null){ writeChar=ch; g.setCharacteristicNotification(ch, true); val d=ch.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")); d?.let{ it.value=BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE; g.writeDescriptor(it) } } }
    override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic){ val s=c.getStringValue(0)?:return; synchronized(buf){ buf.append(s); if (s.contains(">")){ val out=buf.toString(); buf.clear(); scope.launch{ rxChan.send(out) } } } }
  }
  override suspend fun command(cmd:String): ElmResponse {
    writeMutex.lock()
    try{
      val c=writeChar?:return ElmResponse("NO_DEVICE")
      val payload=(cmd+"\r").toByteArray(Charsets.US_ASCII)
      var i=0; val mtu=20
      while(i<payload.size){ val end=(i+mtu).coerceAtMost(payload.size); c.value=payload.copyOfRange(i,end); gatt?.writeCharacteristic(c); i=end; delay(10) }
      val res=withTimeout(2500){ rxChan.receive() }
      return ElmResponse(res)
    } finally { writeMutex.unlock() }
  }
}
object ElmProtocol {
  suspend fun initMode01(elm: ElmTransport): Boolean {
    val seq=listOf("ATZ","ATE0","ATL0","ATS0","ATH0","ATSP0")
    for (cmd in seq){ val r=elm.command(cmd); if (!r.ok) return false }; return true
  }
  suspend fun speed(elm: ElmTransport): Double? {
    val r=elm.command("010D"); val ln=r.cleanLines().firstOrNull{ it.startsWith("41 0D")||it.startsWith("410D") }?:return null
    val hx=ln.replace(" ",""); val b=hx.takeLast(2); return b.toInt(16).toDouble()
  }
  suspend fun ambientTemp(elm: ElmTransport): Double? {
    val r=elm.command("0146"); val ln=r.cleanLines().firstOrNull{ it.startsWith("41 46")||it.startsWith("4146") }?:return null
    val hx=ln.replace(" ",""); val b=hx.takeLast(2); return (b.toInt(16)-40).toDouble()
  }
}
