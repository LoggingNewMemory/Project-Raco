    const messages = [
        "Lag? That’s on you. My connection’s fine",
        "Low ping. Enemies think I cheat",
        "Fast internet, suddenly I play like a god",
        "Enemy lagging? Not my problem",
        "Ping stable, moves get crazy",
        "Low ping, super fast reactions",
        "Fast connection. No excuses to lose",
        "Smooth game, calm ping, enemies panic",
        "Playing chill, still getting kills",
        "Fast internet. Toxic for a reason"
    ];
    function getRandomMessage() {
      return messages[Math.floor(Math.random() * messages.length)];
    }
    function rotateBannerMessage() {
      const el = document.getElementById("banner-message");
      if (el) el.textContent = getRandomMessage();
    }
    // === EXEC HELPER ===
    function exec(command) {
      return new Promise((resolve, reject) => {
        if (typeof ksu === 'undefined' || !ksu.exec) {
          reject(new Error("KSU API not available"));
          return;
        }
        const cbName = `exec_cb_${Date.now()}_${Math.random().toString(36).slice(2)}`;
        window[cbName] = (errno, stdout, stderr) => {
          delete window[cbName];
          if (errno !== 0) {
            reject(new Error(stderr || `Exit ${errno}`));
            return;
          }
          resolve(stdout.trim());
        };
        try {
          ksu.exec(command, "{}", cbName);
        } catch (err) {
          delete window[cbName];
          reject(err);
        }
      });
    }
    // === CUSTOM DROPDOWN INIT ===
    function initDropdown(containerId, options, onSelect) {
      const container = document.getElementById(containerId);
      if (!container) return;
      const trigger = container.querySelector(".custom-dropdown-trigger");
      const menu = container.querySelector(".custom-dropdown-menu");
      const currentText = trigger.querySelector(".current-text");
      let selectedOption = options.find(opt => opt.selected) || options[0];
      if (selectedOption) {
          currentText.textContent = selectedOption.text;
      }
      menu.innerHTML = "";
      options.forEach(opt => {
        const el = document.createElement("div");
        el.className = "custom-dropdown-option";
        el.textContent = opt.text;
        el.dataset.value = opt.value;
        if (opt.selected) el.classList.add("selected");
        el.onclick = () => {
          container.querySelectorAll(".custom-dropdown-option").forEach(o => o.classList.remove("selected"));
          el.classList.add("selected");
          currentText.textContent = opt.text;
          container.classList.remove("open");
          if (onSelect) onSelect(opt.value);
        };
        menu.appendChild(el);
      });
      trigger.onclick = (e) => {
        e.stopPropagation();
        document.querySelectorAll(".custom-dropdown").forEach(d => {
          if (d.id !== containerId) {
            d.classList.remove("open");
          }
        });
        container.classList.toggle("open");
      };
    }
    document.addEventListener("click", () => {
      document.querySelectorAll(".custom-dropdown").forEach(d => d.classList.remove("open"));
    });
    // === TCP ALGORITHM ===
    async function loadTcpAlgorithms() {
      try {
        const available = (await exec("cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null")).trim();
        const current = (await exec("cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null")).trim();
        if (!available) {
          initDropdown("dropdown-tcp", [{ text: "Not available", value: "" }], null);
          return;
        }
        const algos = available.split(/\s+/).filter(x => x);
        const options = algos.map(algo => ({
          value: algo,
          text: algo,
          selected: algo === current 
        }));
        if (options.length === 0) {
            options.push({ text: "Load failed", value: "" });
        }
        initDropdown("dropdown-tcp", options, async (value) => {
          if (value) {
            try {
                await exec(`echo "${value}" > /proc/sys/net/ipv4/tcp_congestion_control`);
            } catch (err) {
                console.error("Failed to set TCP algorithm:", err);
            }
          }
        });
      } catch (err) {
        console.error("Failed to load TCP algorithms:", err);
        initDropdown("dropdown-tcp", [{ text: "Load failed", value: "" }], null);
      }
    }
    // === PRIVATE DNS ===
    const dnsOptions = [
      { value: 'default', text: 'Default' },
      { value: 'cloudflare-standard', text: 'Cloudflare Standard' },
      { value: 'cloudflare-family', text: 'Cloudflare Family' },
      { value: 'cloudflare-security', text: 'Cloudflare Security' },
      { value: 'google', text: 'Google DNS' },
      { value: 'privacy-singapore', text: 'TiarapDNS Singapore' },
      { value: 'privacy-japan', text: 'TiarapDNS Japan' },
      { value: 'adguard', text: 'AdGuard' },
      { value: 'adguard-family', text: 'AdGuard Family' },
      { value: 'adguard-unfiltered', text: 'AdGuard Unfiltered' },
      { value: 'opendns', text: 'OpenDNS' },
      { value: 'quad9-standard', text: 'Quad9 Standard' },
      { value: 'quad9-unsecured', text: 'Quad9 Unsecured' },
      { value: 'quad9-ecs', text: 'Quad9 ECS' },
      { value: 'cleanbrowsing', text: 'CleanBrowsing' },
      { value: 'cleanbrowsing-family', text: 'CleanBrowsing Family' },
      { value: 'cleanbrowsing-adult', text: 'CleanBrowsing Adult' },
      { value: 'cleanbrowsing-security', text: 'CleanBrowsing Security' },
      { value: 'nextdns', text: 'NextDNS' },
      { value: 'nextdns-anycast', text: 'NextDNS Anycast' },
      { value: 'redfish', text: 'Redfish DNS' },
      { value: 'switch', text: 'Switch DNS' },
      { value: 'future', text: 'Future DNS' },
      { value: 'comss-west', text: 'Comss West DNS' },
      { value: 'comss-east', text: 'Comss East DNS' },
      { value: 'cira-private', text: 'CIRA Private' },
      { value: 'cira-protected', text: 'CIRA Protected' },
      { value: 'blah-finland', text: 'Blah DNS Finland' },
      { value: 'blah-japan', text: 'Blah DNS Japan' },
      { value: 'blah-germany', text: 'Blah DNS Germany' },
      { value: 'snopyta', text: 'Snopyta DNS' },
      { value: 'dnsforfamily', text: 'DNS For Family' },
      { value: 'cznic', text: 'CZ.NIC ODVR' },
      { value: 'ali', text: 'AliDNS' },
      { value: 'cfiec', text: 'CFIEC Public DNS' },
      { value: '360', text: '360 Secure DNS' },
      { value: 'iij', text: 'IIJ DNS' },
      { value: 'dnspod', text: 'DNSPod Public DNS+' },
      { value: 'oszx', text: 'OSZX DNS' },
      { value: 'pumplex', text: 'PumpleX DNS' },
      { value: 'applied-privacy', text: 'Applied Privacy DNS' },
      { value: 'decloudus', text: 'DeCloudUs DNS' },
      { value: 'lelux', text: 'Lelux DNS' },
      { value: 'dnsforge', text: 'DNS Forge' },
      { value: 'restena', text: 'Fondation Restena DNS' },
      { value: 'ffmuc', text: 'dot.ffmuc.net', text: 'FFMUC DNS' },
      { value: 'digitale-gesellschaft', text: 'Digitale Gesellschaft DNS' },
      { value: 'libredns', text: 'LibreDNS' },
      { value: 'ibksturm', text: 'ibksturm DNS' },
      { value: 'getdnsapi', text: 'Stubby DNS (getdnsapi.net)' },
      { value: 'sinodun', text: 'dnsovertls.sinodun.com' },
      { value: 'sinodun1', text: 'dnsovertls1.sinodun.com' },
      { value: 'censurfridns-unicast', text: 'UncensoredDNS Unicast' },
      { value: 'censurfridns-anycast', text: 'UncensoredDNS Anycast' },
      { value: 'cmrg', text: 'CMRG DNS' },
      { value: 'larsdebruin', text: 'Lars de Bruin DNS' },
      { value: 'bitwiseshift', text: 'BitwiseShift DNS' },
      { value: 'dnsprivacy1', text: 'DNS Privacy AT 1' },
      { value: 'dnsprivacy2', text: 'DNS Privacy AT 2' },
      { value: 'bitgeek', text: 'BitGeek DNS' },
      { value: 'neutopia', text: 'Neutopia DNS' },
      { value: 'go6lab', text: 'Go6Lab DNS' },
      { value: 'securedns', text: 'SecureDNS EU' },
      { value: 'niccl', text: 'NIC CL DNS' },
      { value: 'oarc', text: 'OARC DNS' },
      { value: 'aha-netherlands', text: 'AhaDNS Netherlands' },
      { value: 'aha-india', text: 'AhaDNS India' },
      { value: 'aha-losangeles', text: 'AhaDNS Los Angeles' },
      { value: 'aha-newyork', text: 'AhaDNS New York' },
      { value: 'aha-poland', text: 'AhaDNS Poland' },
      { value: 'aha-italy', text: 'AhaDNS Italy' },
      { value: 'aha-spain', text: 'AhaDNS Spain' },
      { value: 'aha-norway', text: 'AhaDNS Norway' },
      { value: 'aha-chicago', text: 'AhaDNS Chicago' },
      { value: 'seby', text: 'SebyDNS' },
      { value: 'dnslify', text: 'DNSlify DNS' },
      { value: 'rethink-nonfiltering', text: 'RethinkDNS Non-filtering' },
      { value: 'controld-nonfiltering', text: 'ControlD Non-filtering' },
      { value: 'controld-malware', text: 'ControlD Block Malware' },
      { value: 'controld-ads', text: 'ControlD Block Ads' },
      { value: 'controld-social', text: 'ControlD Block Social' },
      { value: 'mullvad-nonfiltering', text: 'Mullvad Non-filtering' },
      { value: 'mullvad-adblock', text: 'Mullvad Ad Blocking' },
      { value: 'arapurayil', text: 'Arapurayil DNS' },
      { value: 'OpenBLD', text: 'OpenBLD DNS' },
      { value: 'dandelionsprout', text: 'Dandelion Sprout DNS' }
    ];
    const dnsMap = {
      'default': '',
      'cloudflare-standard': 'one.one.one.one',
      'cloudflare-family': 'family.cloudflare-dns.com',
      'cloudflare-security': 'security.cloudflare-dns.com',
      'google': 'dns.google',
      'quad9-standard': 'dns.quad9.net',
      'quad9-unsecured': 'dns10.quad9.net',
      'quad9-ecs': 'dns11.quad9.net',
      'cleanbrowsing': 'doh.cleanbrowsing.org',
      'cleanbrowsing-family': 'family-filter-dns.cleanbrowsing.org',
      'cleanbrowsing-adult': 'adult-filter-dns.cleanbrowsing.org',
      'cleanbrowsing-security': 'security-filter-dns.cleanbrowsing.org',
      'nextdns': 'dns.nextdns.io',
      'nextdns-anycast': 'anycast.dns.nextdns.io',
      'adguard': 'dns.adguard-dns.com',
      'adguard-family': 'family.adguard-dns.com',
      'adguard-unfiltered': 'unfiltered.adguard-dns.com',
      'opendns': 'dns.opendns.com',
      'redfish': 'dns.rubyfish.cn',
      'switch': 'dns.switch.ch',
      'future': 'dns.futuredns.me',
      'comss-west': 'dns.comss.one',
      'comss-east': 'dns.east.comss.one',
      'cira-private': 'family.canadianshield.cira.ca',
      'cira-protected': 'protected.canadianshield.cira.ca',
      'blah-finland': 'dot-fi.blahdns.com',
      'blah-japan': 'dot-jp.blahdns.com',
      'blah-germany': 'dot-de.blahdns.com',
      'snopyta': 'fi.dot.dns.snopyta.org',
      'dnsforfamily': 'dns-dot.dnsforfamily.com',
      'cznic': 'odvr.nic.cz',
      'ali': 'dns.alidns.com',
      'cfiec': 'dns.cfiec.net',
      '360': 'dot.360.cn',
      'iij': 'public.dns.iij.jp',
      'dnspod': 'dot.pub',
      'privacy-singapore': 'dot.tiarap.org',
      'privacy-japan': 'jp.tiar.app',
      'oszx': 'dns.oszx.co',
      'pumplex': 'dns.pumplex.com',
      'applied-privacy': 'dot1.applied-privacy.net',
      'decloudus': 'dns.decloudus.com',
      'lelux': 'resolver-eu.lelux.fi',
      'dnsforge': 'dnsforge.de',
      'restena': 'kaitain.restena.lu',
      'ffmuc': 'dot.ffmuc.net',
      'digitale-gesellschaft': 'dns.digitale-gesellschaft.ch',
      'libredns': 'dot.libredns.gr',
      'ibksturm': 'ibksturm.synology.me',
      'getdnsapi': 'getdnsapi.net',
      'sinodun': 'dnsovertls.sinodun.com',
      'sinodun1': 'dnsovertls1.sinodun.com',
      'censurfridns-unicast': 'unicast.censurfridns.dk',
      'censurfridns-anycast': 'anycast.censurfridns.dk',
      'cmrg': 'dns.cmrg.net',
      'larsdebruin': 'dns.larsdebruin.net',
      'bitwiseshift': 'dns-tls.bitwiseshift.net',
      'dnsprivacy1': 'ns1.dnsprivacy.at',
      'dnsprivacy2': 'ns2.dnsprivacy.at',
      'bitgeek': 'dns.bitgeek.in',
      'neutopia': 'dns.neutopia.org',
      'go6lab': 'privacydns.go6lab.si',
      'securedns': 'dot.securedns.eu',
      'niccl': 'dnsotls.lab.nic.cl',
      'oarc': 'tls-dns-u.odvr.dns-oarc.net',
      'aha-netherlands': 'dot.nl.ahadns.net',
      'aha-india': 'dot.in.ahadns.net',
      'aha-losangeles': 'dot.la.ahadns.net',
      'aha-newyork': 'dot.ny.ahadns.net',
      'aha-poland': 'dot.pl.ahadns.net',
      'aha-italy': 'dot.it.ahadns.net',
      'aha-spain': 'dot.es.ahadns.net',
      'aha-norway': 'dot.no.ahadns.net',
      'aha-chicago': 'dot.chi.ahadns.net',
      'seby': 'dot.seby.io',
      'dnslify': 'doh.dnslify.com',
      'rethink-nonfiltering': 'max.rethinkdns.com',
      'controld-nonfiltering': 'p0.freedns.controld.com',
      'controld-malware': 'p1.freedns.controld.com',
      'controld-ads': 'p2.freedns.controld.com',
      'controld-social': 'p3.freedns.controld.com',
      'mullvad-nonfiltering': 'doh.mullvad.net',
      'mullvad-adblock': 'adblock.doh.mullvad.net',
      'arapurayil': 'dns.arapurayil.com',
      'OpenBLD': 'ric.openbld.net',
      'dandelionsprout': 'dandelionsprout.asuscomm.com'
    };
    function loadPrivateDnsOptions() {
      const savedValue = localStorage.getItem('pingpimp_dns') || 'default';
      const options = dnsOptions.map(opt => ({
        ...opt,
        selected: opt.value === savedValue
      }));
      initDropdown("dropdown-dns", options, async (value) => {
        localStorage.setItem('pingpimp_dns', value);
        const dotName = dnsMap[value] || '';
        if (value === 'default') {
          try {
            await exec(`settings delete global private_dns_mode`);
            await exec(`settings delete global private_dns_specifier`);
          } catch (e) {
            console.warn("Failed to reset DNS:", e);
          }
        } else {
          try {
            await exec(`settings put global private_dns_mode hostname`);
            await exec(`settings put global private_dns_specifier ${dotName}`);
          } catch (e) {
            console.warn("Failed to set DNS:", e);
          }
        }
      });
      const initialDnsName = dnsMap[savedValue] || '';
      if (savedValue === 'default') {
        exec(`settings delete global private_dns_mode`);
        exec(`settings delete global private_dns_specifier`);
      } else {
        exec(`settings put global private_dns_mode hostname`);
        exec(`settings put global private_dns_specifier ${initialDnsName}`);
      }
    }
    // === PRESET TWEAK ===
    const presetOptions = [
      { value: 'default', text: 'Default' },
      { value: 'game', text: 'Game' },
      { value: 'download', text: 'Download' },
      { value: 'streaming', text: 'Streaming' },
      { value: 'media sosial', text: 'Media Sosial' },
      { value: 'browsing', text: 'Browsing' },
      { value: 'out door', text: 'Out Door' }
    ];
    function getPresetCommand(value) {
        if (value === 'media sosial') {
            return 'PingPimp --social';
        } else if (value === 'out door') {
            return 'PingPimp --outdoor';
        } else if (value !== 'default') {
            return `PingPimp --${value.toLowerCase().replace(/[^a-z0-9]/g, '')}`;
        } else {
            return 'PingPimp --default';
        }
    }
    async function loadPresetTweakOptions() {
      let currentPreset = 'default';
      try {
        const content = await exec("cat /data/adb/modules/PingPimp/preset.txt 2>/dev/null");
        currentPreset = (content || 'default').trim();
      } catch (e) {
        console.warn("Failed to read preset.txt, using default");
      }
      const options = presetOptions.map(opt => ({
        ...opt,
        selected: opt.value === currentPreset
      }));
      initDropdown("dropdown-preset", options, async (value) => {
        try {
          await exec(`echo "${value}" > /data/adb/modules/PingPimp/preset.txt`);
          const command = getPresetCommand(value);
          console.log(`Executing preset command: ${command}`);
          await exec(command);
        } catch (err) {
          console.error(`Failed to save preset or execute command for ${value}:`, err);
        }
      });
    }
    // === DISABLE NETWORK STATE SWITCH ===
    async function initNetStateSwitch() {
      const switchEl = document.getElementById("switch-netstate");
      if (!switchEl) return;
      try {
        const content = await exec("cat /data/adb/modules/PingPimp/state.txt 2>/dev/null");
        const value = content.trim();
        switchEl.checked = value === "1";
      } catch (e) {
        switchEl.checked = false;
      }
      switchEl.onchange = async () => {
        const val = switchEl.checked ? "1" : "0";
        let command = switchEl.checked ? 'PingPimp --state' : 'PingPimp --unstate';
        try {
          await exec(`echo "${val}" > /data/adb/modules/PingPimp/state.txt`);
          console.log(`Executing net state command: ${command}`);
          await exec(command);
        } catch (err) {
          console.error(`Failed to save state.txt or execute command: ${command}`, err);
          switchEl.checked = !switchEl.checked;
        }
      };
    }
    // === ULTRA DATA SAVER SWITCH ===
    async function initDataSaverSwitch() {
      const switchEl = document.getElementById("switch-saver");
      if (!switchEl) return;
      try {
        const content = await exec("cat /data/adb/modules/PingPimp/saver.txt 2>/dev/null");
        const value = content.trim();
        switchEl.checked = value === "1";
      } catch (e) {
        switchEl.checked = false;
      }
      switchEl.onchange = async () => {
        const val = switchEl.checked ? "1" : "0";
        let command = switchEl.checked ? 'PingPimp --saver' : 'PingPimp --unsaver';
        try {
          await exec(`echo "${val}" > /data/adb/modules/PingPimp/saver.txt`);
          console.log(`Executing data saver command: ${command}`);
          await exec(command);
        } catch (err) {
          console.error(`Failed to toggle data saver:`, err);
          switchEl.checked = !switchEl.checked;
        }
      };
    }
    // === DEVICE INFO ===
    async function updatePingPimpVersion() {
      try {
        const content = await exec("cat /data/adb/modules/PingPimp/module.prop 2>/dev/null | grep '^version=' || echo 'version=Unknown'");
        document.getElementById("PingPimpVer").textContent = content.replace("version=", "").trim() || "Unknown";
      } catch (e) {
        document.getElementById("PingPimpVer").textContent = "Unknown";
      }
    }
    async function updateDeviceInfo() {
      const props = [
        ["ro.product.model", "device-model"],
        ["ro.build.version.release", "device-android"],
        ["ro.board.platform", "device-chipset"],
        ["ro.product.cpu.abilist", "device-abis"]
      ];
      try {
        document.getElementById("device-kernel").textContent = (await exec("uname -r 2>/dev/null || echo '-'")).trim() || "-";
        for (const [prop, id] of props) {
          try {
            const val = (await exec(`getprop ${prop} 2>/dev/null || echo '-'`)).trim() || "-";
            document.getElementById(id).textContent = val;
          } catch {
            document.getElementById(id).textContent = "-";
          }
        }
      } catch (e) {
        console.warn("Partial device info fetch failed", e);
      }
    }
    // === ISOLATE LOGIC ===
    let selectedApps = new Set();
    let currentMode = 'system';
    async function listPackages(flag) {
      const cmd = flag === 'system'
        ? "pm list packages -s | cut -f2 -d:"
        : "pm list packages -3 | cut -f2 -d:";
      try {
        const raw = await exec(cmd);
        return raw.split('\n').filter(p => p.trim()).sort();
      } catch (err) {
        console.error("Failed to list packages:", err);
        return [];
      }
    }
    async function getAppUid(packageName) {
      try {
        const dumpResult = await exec(`dumpsys package ${packageName} | grep 'userId=' | head -1`);
        const match = dumpResult.match(/userId=(\d+)/);
        if (match && match[1]) {
          return match[1];
        }
        const uidResult = await exec(`grep "^${packageName}" /data/system/packages.list | awk '{print $2; exit}'`);
        return uidResult.trim() || null;
      } catch (error) {
        console.error(`Failed to get UID for ${packageName}:`, error);
        return null;
      }
    }
    async function getIsolatedPackages() {
        const packages = new Set();
        try {
            const savedIsolationList = localStorage.getItem('pingpimp_isolated_apps');
            if (savedIsolationList) {
                savedIsolationList.split(',').forEach(pkg => packages.add(pkg));
            }
        } catch (e) {
            console.warn("Failed to retrieve isolated packages:", e);
        }
        return packages;
    }
    function saveIsolatedPackages() {
        localStorage.setItem('pingpimp_isolated_apps', Array.from(selectedApps).join(','));
    }
    function renderAppList(packages) {
      const container = document.getElementById("app-list-container");
      const query = document.getElementById("isolate-search").value.toLowerCase().trim();
      const filtered = query
        ? packages.filter(pkg => pkg.toLowerCase().includes(query))
        : packages;
      container.innerHTML = filtered.map(pkg => `
        <div class="isolate-app-item" style="display:flex;align-items:center;justify-content:space-between;padding:14px 16px;background:var(--card-bg);margin-bottom:4px;">
          <div class="isolate-app-label" style="font-size:14px;font-weight:500;color:var(--on-surface);max-width:calc(100% - 60px);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${pkg}</div>
          <label class="custom-switch">
            <input type="checkbox" ${selectedApps.has(pkg) ? 'checked' : ''} data-pkg="${pkg}">
            <span class="switch-slider"></span>
          </label>
        </div>
      `).join('');
      container.querySelectorAll('input[type="checkbox"]').forEach(checkbox => {
        checkbox.addEventListener('change', async (e) => {
          const pkg = e.target.dataset.pkg;
          const uid = await getAppUid(pkg);
          if (e.target.checked) {
            if (uid) {
              await exec(`iptables -I OUTPUT -m owner --uid-owner ${uid} -j REJECT`);
              await exec(`ip6tables -I OUTPUT -m owner --uid-owner ${uid} -j REJECT`);
            }
            selectedApps.add(pkg);
          } else {
            if (uid) {
              await exec(`iptables -D OUTPUT -m owner --uid-owner ${uid} -j REJECT 2>/dev/null || true`);
              await exec(`ip6tables -D OUTPUT -m owner --uid-owner ${uid} -j REJECT 2>/dev/null || true`);
            }
            selectedApps.delete(pkg);
          }
          saveIsolatedPackages();
        });
      });
    }
    function renderSelectedApps() {
      const container = document.getElementById("selected-apps-container");
      container.innerHTML = '';
      selectedApps.forEach(pkg => {
        const chip = document.createElement("div");
        chip.className = "selected-app-chip";
        chip.style.padding = "6px 12px";
        chip.style.borderRadius = "16px";
        chip.style.background = "var(--primary-container)";
        chip.style.color = "var(--on-primary-container)";
        chip.style.fontSize = "13px";
        chip.style.fontWeight = "500";
        chip.style.cursor = "pointer";
        chip.style.display = "inline-flex";
        chip.style.alignItems = "center";
        chip.style.gap = "6px";
        chip.textContent = pkg;
        chip.onclick = async () => {
          selectedApps.delete(pkg);
          saveIsolatedPackages();
          renderSelectedApps();
          const uid = await getAppUid(pkg);
          if (uid) {
            await exec(`iptables -D OUTPUT -m owner --uid-owner ${uid} -j REJECT 2>/dev/null || true`);
            await exec(`ip6tables -D OUTPUT -m owner --uid-owner ${uid} -j REJECT 2>/dev/null || true`);
          }
        };
        container.appendChild(chip);
      });
    }
    // === TAB NAVIGATION ===
    function showTab(tabId) {
      document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
      document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
      document.getElementById(`tab-${tabId}`).classList.add('active');
      document.getElementById(`nav-${tabId}`).classList.add('active');
    }
    async function openUrl(url) {
      try {
        await exec(`am start -a android.intent.action.VIEW -d '${url}'`);
      } catch (e) {
        window.open(url, "_blank");
      }
    }
    // === INIT ===
    document.addEventListener("DOMContentLoaded", async () => {
      const loadingOverlay = document.getElementById('loading-overlay');
      selectedApps = await getIsolatedPackages();
      await Promise.all([
        updatePingPimpVersion(),
        updateDeviceInfo(),
        loadPresetTweakOptions(),
        loadTcpAlgorithms(),
        loadPrivateDnsOptions(),
        initNetStateSwitch(),
        initDataSaverSwitch()
      ]);
      rotateBannerMessage();
      setInterval(rotateBannerMessage, 7000);
      document.getElementById("btn-github").onclick = (e) => {
        e.preventDefault();
        openUrl("https://github.com/fuckyoustan");
      };
      document.getElementById("btn-telegram").onclick = (e) => {
        e.preventDefault();
        openUrl("tg://resolve?domain=EverythingAboutArchive");
      };
      document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', () => {
          const tabId = item.id.replace('nav-', '');
          showTab(tabId);
        });
      });
      const chipButtons = document.querySelectorAll('.filter-chip');
      const selectedContainer = document.getElementById("selected-apps-container");
      const appListContainer = document.getElementById("app-list-container");
      document.querySelector('.filter-chip[data-chip="system"]').classList.add('active');
      currentMode = 'system';
      const systemPkgs = await listPackages('system');
      renderAppList(systemPkgs);
      chipButtons.forEach(btn => {
        btn.addEventListener('click', async () => {
          chipButtons.forEach(b => b.classList.remove('active'));
          btn.classList.add('active');
          currentMode = btn.dataset.chip;
          if (currentMode === 'list') {
            appListContainer.innerHTML = '';
            renderSelectedApps();
            selectedContainer.style.display = 'flex';
          } else {
            selectedContainer.style.display = 'none';
            const pkgs = await listPackages(currentMode);
            renderAppList(pkgs);
          }
        });
      });
      document.getElementById("isolate-search").addEventListener("input", async () => {
        if (currentMode === 'system' || currentMode === 'user') {
          const pkgs = await listPackages(currentMode);
          renderAppList(pkgs);
        }
      });
      loadingOverlay.style.transition = "opacity 0.3s ease";
      loadingOverlay.style.opacity = "0";
      setTimeout(() => {
        if (loadingOverlay.parentNode) {
          loadingOverlay.parentNode.removeChild(loadingOverlay);
        }
      }, 300);
    });