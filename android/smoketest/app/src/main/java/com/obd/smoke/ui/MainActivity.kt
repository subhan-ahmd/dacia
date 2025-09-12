@file:OptIn(ExperimentalMaterial3Api::class)

package com.obd.smoke.ui

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.obd.smoke.ble.BleElmService
import com.obd.smoke.ble.ElmProtocol
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Locale

class MainActivity : ComponentActivity() {

  private val permLauncher =
    registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    requestBlePerms()
    startForegroundService(android.content.Intent(this, BleElmService::class.java))

    setContent {
      MaterialTheme {
        val scope = rememberCoroutineScope()
        var status by remember { mutableStateOf("Idle") }
        var devices by remember { mutableStateOf(listOf<String>()) }
        var selected by remember { mutableStateOf<String?>(null) }
        var speed by remember { mutableStateOf<Double?>(null) }
        var amb by remember { mutableStateOf<Double?>(null) }

        Scaffold(topBar = { TopAppBar(title = { Text("OBD Smoke Test") }) }) { pad ->
          Column(Modifier.padding(pad).padding(16.dp)) {
            Text("Status: $status", fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(12.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
              Button(onClick = {
                BleElmService.instance?.scan(this@MainActivity) { list -> devices = list }
                status = "Scanning…"
              }) { Text("Scan") }

              Spacer(Modifier.width(8.dp))

              var expanded by remember { mutableStateOf(false) }
              ExposedDropdownMenuBox(
                expanded = expanded,
                onExpandedChange = { expanded = !expanded }
              ) {
                OutlinedTextField(
                  readOnly = true,
                  value = selected ?: "Select device",
                  onValueChange = {},
                  label = { Text("vLinker BM+") },
                  // New API: provide type + enabled flags
                  modifier = Modifier
                    .menuAnchor(MenuAnchorType.PrimaryNotEditable, enabled = true)
                    .weight(1f)
                )
                ExposedDropdownMenu(
                  expanded = expanded,
                  onDismissRequest = { expanded = false }
                ) {
                  devices.forEach { d ->
                    DropdownMenuItem(
                      text = { Text(d) },
                      onClick = {
                        selected = d
                        expanded = false
                        BleElmService.instance?.pickDevice(d)
                      }
                    )
                  }
                }
              }

              Spacer(Modifier.width(8.dp))

              Button(onClick = {
                BleElmService.instance?.connectPreferred(this@MainActivity)
                status = "Connecting…"
              }) { Text("Connect") }
            }

            Spacer(Modifier.height(16.dp))

            Row {
              Button(onClick = {
                status = "Init Mode01…"
                val elm = BleElmService.instance?.elm ?: return@Button
                scope.launch(Dispatchers.IO) {
                  val ok = ElmProtocol.initMode01(elm)
                  status = if (ok) "Mode01 OK" else "Mode01 failed"
                }
              }) { Text("Init") }

              Spacer(Modifier.width(8.dp))

              Button(onClick = {
                val elm = BleElmService.instance?.elm ?: return@Button
                scope.launch(Dispatchers.IO) {
                  speed = ElmProtocol.speed(elm)
                  amb = ElmProtocol.ambientTemp(elm)
                  status = "Read once"
                }
              }) { Text("Read Once") }
            }

            Spacer(Modifier.height(16.dp))

            LazyColumn {
              item {
                Tile(
                  "Speed (km/h)",
                  speed?.let { String.format(Locale.US, "%.0f", it) } ?: "--"
                )
              }
              item {
                Tile(
                  "Ambient (°C)",
                  amb?.let { String.format(Locale.US, "%.1f", it) } ?: "--"
                )
              }
            }
          }
        }
      }
    }
  }

  @Composable
  private fun Tile(title: String, value: String) {
    Card(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
      Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, modifier = Modifier.weight(1f))
        Text(value, fontWeight = FontWeight.Bold)
      }
    }
  }

  private fun requestBlePerms() {
    val perms = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      perms += Manifest.permission.BLUETOOTH_CONNECT
      perms += Manifest.permission.BLUETOOTH_SCAN
    }
    permLauncher.launch(perms.toTypedArray())
  }
}
