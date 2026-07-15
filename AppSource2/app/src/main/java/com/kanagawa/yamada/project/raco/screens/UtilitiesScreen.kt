package com.kanagawa.yamada.project.raco.screens

import com.kanagawa.yamada.project.raco.R
import androidx.compose.ui.res.stringResource

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class UtilityItem(
    val title: String,
    val subtitle: String,
    val icon: ImageVector,
    val route: UtilityRoute,
    val keywords: String
)

enum class UtilityRoute {
    CoreTweaks, Automation, System, Appearance, ExtraSettings
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UtilitiesScreen(onBack: () -> Unit) {
    var hasRoot by remember { mutableStateOf(false) }
    var isLoaded by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }
    var currentRoute by remember { mutableStateOf<UtilityRoute?>(null) }
    val coroutineScope = rememberCoroutineScope()

    val categories = listOf(
        UtilityItem(stringResource(R.string.core_tweaks_title), stringResource(R.string.util_desc_core_tweaks), Icons.Default.Tune, UtilityRoute.CoreTweaks, stringResource(R.string.util_kw_core_tweaks)),
        UtilityItem(stringResource(R.string.automation_title), stringResource(R.string.util_desc_automation), Icons.Default.SmartToy, UtilityRoute.Automation, stringResource(R.string.util_kw_automation)),
        UtilityItem(stringResource(R.string.system_title), stringResource(R.string.util_desc_system), Icons.Default.Settings, UtilityRoute.System, stringResource(R.string.util_kw_system)),
        UtilityItem(stringResource(R.string.appearance_title), stringResource(R.string.util_desc_appearance), Icons.Default.ColorLens, UtilityRoute.Appearance, stringResource(R.string.util_kw_appearance)),
        UtilityItem(stringResource(R.string.extra_settings_title), stringResource(R.string.util_desc_extra_settings), Icons.Default.BuildCircle, UtilityRoute.ExtraSettings, stringResource(R.string.util_kw_extra_settings))
    )

    LaunchedEffect(Unit) {
        coroutineScope.launch {
            hasRoot = withContext(Dispatchers.IO) {
                try {
                    val p = ProcessBuilder("su", "-c", "id").redirectErrorStream(true).start()
                    p.outputStream.close()
                    val out = p.inputStream.bufferedReader().use { it.readText() }
                    p.waitFor()
                    out.contains("uid=0")
                } catch (e: Exception) { false }
            }
            isLoaded = true
        }
    }

    // Navigate to sub-screen
    currentRoute?.let { route ->
        when (route) {
            UtilityRoute.CoreTweaks -> CoreTweaksScreen(onBack = { currentRoute = null })
            UtilityRoute.Automation -> AutomationScreen(onBack = { currentRoute = null })
            UtilityRoute.System -> SystemScreen(onBack = { currentRoute = null })
            UtilityRoute.Appearance -> AppearanceScreen(onBack = { currentRoute = null })
            UtilityRoute.ExtraSettings -> ExtraSettingsScreen(onBack = { currentRoute = null })
        }
        return
    }

    val filteredItems = if (searchQuery.isBlank()) {
        categories
    } else {
        val terms = searchQuery.lowercase().split(" ").filter { it.isNotEmpty() }
        categories.filter { item ->
            val combined = (item.title + " " + item.subtitle + " " + item.keywords).lowercase()
            terms.all { term -> combined.contains(term) }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(stringResource(R.string.utilities_title))
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = MaterialTheme.colorScheme.primary,
                    navigationIconContentColor = MaterialTheme.colorScheme.primary
                )
            )
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { padding ->
        val context = androidx.compose.ui.platform.LocalContext.current
        val sharedPrefs = context.getSharedPreferences("raco_app_config", android.content.Context.MODE_PRIVATE)

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
            ) {
                if (!isLoaded) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                }
                return@Column
            }

            if (!hasRoot) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(stringResource(R.string.error_no_root), color = MaterialTheme.colorScheme.error)
                }
                return@Column
            }

            // Search bar
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = { Text(stringResource(R.string.search_utilities_1)) },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                shape = RoundedCornerShape(30.dp),
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    unfocusedBorderColor = MaterialTheme.colorScheme.surfaceVariant
                )
            )

            if (filteredItems.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(stringResource(R.string.no_results_found_1), color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(filteredItems) { item ->
                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { currentRoute = item.route }
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(item.icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(28.dp))
                                Spacer(modifier = Modifier.width(16.dp))
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(item.title, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(item.subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Spacer(modifier = Modifier.width(8.dp))
                                Icon(Icons.Default.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }
        }
    }
}
