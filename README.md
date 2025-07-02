Below is the translated `README.md` in English, maintaining the original structure and formatting as closely as possible:

---

# Hi Hysteria
##### (2025/06/09) 1.0.3

```
Compatible with Hysteria 2.6.2 update. New features include TLS ClientHello fragmentation for enhanced anti-blocking, preventing UDP QoS based on domain names.

1. Compatible with servers using LXC and OpenVZ virtualization for installing hy2 with hihy.
2. Fixed incorrect local certificate path.
3. Fixed hy2 status detection error when using Arch.
4. Use domain sniffing to prevent ACL routing failures.
5. Disable fastOpen in `mode auto` outbound to avoid IPv4-only resolution issues.
```

[Change Log](md/log.md)

[Hysteria V1 Version](https://github.com/emptysuns/Hi_Hysteria/tree/v1)

## 1. Introduction

> Hysteria2 is a feature-rich network tool optimized for harsh network environments (dual-sided acceleration), such as satellite networks, congested public Wi-Fi, and **connecting to foreign servers from China**. It is based on a modified QUIC protocol.
>
> It effectively addresses the biggest pain point when setting up advanced proxy servers—**poor network quality**.

1. Direct connection to a JP NTT data center + Cloudflare Warp, no optimization for China Telecom (163) lines, tested with Speedtest during peak hours (20:00–23:00):

~~Due to the test machine being an LXC container with limited performance, the CPU was fully utilized and could not perform further.~~

![image](imgs/speed.png)

2. No optimization for mainland China routes, Los Angeles ShockHosting data center, 1-core 128MB OVZ NAT, 4K@60fps:

![image](imgs/yt.jpg)

```
139783 Kbps
```

**This repository is for learning purposes only, aimed at studying optimization methods and solutions for high-jitter, high-latency network environments. It is strictly prohibited for illegal activities. Please comply with the laws of your jurisdiction.**

The author assumes no risk or legal liability for any issues arising from its use. Please adhere to the GPL open-source license.

There may be some bugs. If you encounter any, please report them via an issue. Stars are welcome—your ⭐ is my motivation to maintain this project.

## 2. Advantages

<details>
<summary><b>Click to expand and view the complete feature list</b></summary>

* Supports all three masquerade modes provided by Hysteria2 with highly customizable masquerade content.
* Offers four certificate import methods:
  * ACME HTTP challenge
  * ACME DNS
  * Self-signed certificate for any domain
  * Local certificate
* Supports viewing Hysteria2 server statistics in the SSH terminal:
  * User traffic statistics
  * Number of online devices
  * Current active connections
* Provides domain routing rules via ACL and blocks requests to specific domains.
* Supports all mainstream operating systems and architectures:
  * Operating Systems: Arch, Alpine, RHEL, CentOS, AlmaLinux, Debian, Ubuntu, Rocky Linux, etc.
  * Architectures: x86_64, i386|i686, aarch64|arm64, armv7, s390x, ppc64le
* Supports generating QR codes for hy2 share links in the terminal, reducing tedious copy-paste operations.
* Supports generating Hysteria2 original client configuration files, retaining the most comprehensive client parameters.
* Starts Hysteria2 processes with high priority to prioritize speed.
* Manages port hopping and Hysteria2 daemon with startup scripts for enhanced scalability and compatibility.
* Retains installation scripts for Hysteria v1 for user choice.
* Calculates BDP (Bandwidth-Delay Product) to adjust QUIC parameters for various use cases.
* Supports adding SOCKS5 outbound, including automatic Warp outbound configuration.
* Supports all mainstream virtualization methods: LXC, OpenVZ, KVM, etc.
* Timely updates, with adaptations completed within 24 hours of Hysteria2 updates.

</details>

## 3. Usage

### First Time Using?

#### 1. [Firewall Issues](md/firewall.md)

#### 2. [Self-Signed Certificates](md/certificate.md)

#### 3. [List of Service Providers Restricting UDP (Updated 2025/01/07)](md/blacklist.md)

#### 4. [How to Set Latency, Upload, and Download Speeds?](md/speed.md)

#### 5. [Supported Clients](md/client.md)

#### 6. [Common Issues](md/issues.md)

#### 7. [Setting Up a Masquerade Website](md/masquerade.md)

### Installation

```
bash <(curl -fsSL https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main/server/install.sh)
```

### Configuration Process

After the first installation, use the `hihy` command to bring up the menu. If the hihy script is updated, select option `9` to get the latest configuration.

You can directly access functions by entering their number, e.g., `hihy 5` to restart Hysteria2.

```
 -------------------------------------------
|**********      Hi Hysteria       **********|
|**********    Author: emptysuns   **********|
|**********     Version: 1.0.3     **********|
 -------------------------------------------
Tips: Run `hihy` to execute this script again.
............................................. 
############################### 
..................... 
1) Install Hysteria2 
2) Uninstall 
..................... 
3) Start 
4) Stop 
5) Restart 
6) Check Status 
..................... 
7) Update Core 
8) View Current Configuration 
9) Reconfigure 
10) Switch IPv4/IPv6 Priority 
11) Update hihy 
12) Domain Routing/ACL Management 
13) View Hysteria2 Statistics 
14) View Real-Time Logs 
15) Add SOCKS5 Outbound [Supports Auto Warp Configuration] 
############################### 
0) Exit 
............................................. 
Please select:
```

**The script may change with each update. Please carefully review the demonstration process to avoid unnecessary errors!**

<details>
  <summary>The demonstration is lengthy, click to view</summary>
<pre><blockcode> 

(1/11) Please select the certificate application method:

1) Use ACME (recommended, requires TCP 80/443 open)
2) Use local certificate file
3) Self-signed certificate
4) DNS verification

Enter number:
3
Enter the domain for the self-signed certificate (default: apple.com): 
pornhub.a.com     
-> Self-signed certificate domain: pornhub.a.com 

Is the address used for client connection correct? Public IP: 1.2.3.4
Please select:

1) Correct (default)
2) Incorrect, manually enter IP

Enter number:
1

-> You have selected self-signed pornhub.a.com certificate encryption. Public IP: 1.2.3.4

(2/11) Enter the port you want to open (server port, recommended: 443, default: random 10000-65535) 
There is no evidence that non-UDP/443 ports are blocked; it’s merely a better masquerade measure. If using port hopping, a random port is recommended.

-> Using random port: udp/43956 

-> (3/11) Enable Port Hopping? Recommended. 
Tip: Long-term single-port UDP connections are prone to ISP blocking/QoS/disconnection. Enabling this feature effectively avoids this issue.
For more details, refer to: https://v2.hysteria.network/en/docs/advanced/Port-Hopping/

Select whether to enable:

1) Enable (default)
2) Skip

Enter number:

-> You have chosen to enable Port Hopping/Multi-Port functionality 
Port Hopping requires multiple ports. Ensure these ports are not used by other services.
Tip: Do not select too many ports; around 1000 is recommended, within the range 1-65535. Continuous port ranges are suggested.

Enter start port (default: 47000): 
31000

-> Start port: 31000 

Enter end port (default: 48000): 
32000

-> End port: 32000 

-> Your Port Hopping parameters: 31000:32000 

(4/11) Enter the average latency to this server, which affects forwarding speed (default: 200, unit: ms): 
280

-> Latency: 280 ms

Expected speed is the client’s peak speed; the server is unlimited by default. Tip: The script automatically adds 10% redundancy. Setting it too low or too high affects forwarding efficiency—please enter accurate values!
(5/11) Enter the desired client download speed (default: 50, unit: mbps): 
250

-> Client download speed: 250 mbps

(6/11) Enter the desired client upload speed (default: 10, unit: mbps): 
30

-> Client upload speed: 30 mbps

(7/11) Enter the authentication password (default: random UUID, strong password recommended): 

-> Authentication password: 5a399adf-e12b-450b-8c39-ef11cc566179 

Tip: Using obfuscation (salamander) enhances anti-blocking but increases CPU load, reducing peak speed. If performance is prioritized and no targeted blocking exists, avoid using it.
(8/11) Use salamander for traffic obfuscation:

1) Do not use (recommended)
2) Use

Enter number:

-> You have chosen not to use obfuscation

(9/11) Select masquerade type:

1) String (default, returns a fixed string)
2) Proxy (acts as a reverse proxy, serving content from another website)
3) File (acts as a static file server, serving content from a directory containing index.html)

Enter number:
2
Enter the masquerade proxy address (default: https://www.helloworld.org): 
Proxies this URL without replacing domains in the webpage
https://github.com

-> Masquerade proxy address: https://github.com 

(10/11) Listen on tcp/43956 to enhance masquerade behavior (complete the act): 
Typically, websites support HTTP/3 as an upgrade option. 
Listening on a TCP port provides masquerade content, making it more natural. If disabled, browsers cannot access masquerade content without H3.
Please select:

1) Enable (default)
2) Skip

Enter number:

-> You have chosen to listen on tcp/43956

(11/11) Enter client name remark (default: uses domain or IP, e.g., entering test results in Hy2-test): 
test

Configuration completed!

Executing configuration... 
Generating self-signed certificate...

Generating CA private key... 
Generating RSA private key, 2048 bit long modulus (2 primes)
Generating CA certificate... 
Can't load /root/.rnd into RNG
281012468479616:error:2406F079:random number generator:RAND_load_file:Cannot open file:../crypto/rand/randfile.c:88:Filename=/root/.rnd
Generating server private key and CSR... 
Can't load /root/.rnd into RNG
280948454311552:error:2406F079:random number generator:RAND_load_file:Cannot open file:../crypto/rand/randfile.c:88:Filename=/root/.rnd
Generating a RSA private key
writing new private key to '/etc/hihy/cert/pornhub.a.com.key'
Signing server certificate with CA... 
Signature ok
subject=C = CN, ST = GuangDong, L = ShenZhen, O = PonyMa, OU = Tecent, emailAddress = no-reply@qq.com, CN = pornhub.a.com
Getting CA Private Key
Cleaning up temporary files... 
Moving CA certificate to result directory... 
Certificate generation successful!

net.core.rmem_max = 77000000
net.core.wmem_max = 77000000
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

Test config...

Test success! 
Port Hopping NAT rules added and persisted. 
IPTABLES OPEN: udp/43956 
run-parts: executing /usr/share/netfilter-persistent/plugins.d/15-ip4tables save
run-parts: executing /usr/share/netfilter-persistent/plugins.d/25-ip6tables save
IPTABLES OPEN: tcp/43956 
run-parts: executing /usr/share/netfilter-persistent/plugins.d/15-ip4tables save
run-parts: executing /usr/share/netfilter-persistent/plugins.d/25-ip6tables save
Generating config... 
install.sh: line 305: 21873 Terminated              /etc/hihy/bin/appS -c ${yaml_file} server > ./hihy_debug.info 2>&1
Installation successful. See configuration details below.
Starting hihy...
Started successfully!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 Generating client configuration...

✨ Configuration details:

📌 Current Hysteria2 server version: app/v2.6.0 
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️ Security Notice:
🔒 You are using a self-signed certificate, requiring:
   1. Manually trusting the certificate in the browser
   2. Setting hosts to point the IP to the domain

🌐 1. Masquerade address: https://1.2.3.48:43956  

🔗 2. [v2rayN-Windows/v2rayN-Android/nekobox/passwall/Shadowrocket] Share link:
 
hy2://5a399adf-e12b-450b-8c39-ef11cc566179@1.2.3.48:43956/?mport=31000-32000&insecure=1&sni=pornhub.a.com#Hy2-test 

█ ▄▄▄▄▄ █▀▀▄▄▄██  █ ▀▀▄▄▄ █▄▀▀█▄▄▄█ ▄▄▄▄▄ █

QR code generated successfully. 

📄 3. [Recommended] [Nekoray/V2rayN/NekoBoxforAndroid] Native configuration file, fastest updates, most comprehensive parameters, best performance. File location: ./Hy2-test-v2rayN.yaml  
↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓COPY↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ 
server: hysteria2://5a399adf-e12b-450b-8c39-ef11cc566179@1.2.3.48:43956,31000-32000/
tls:
  sni: pornhub.a.com
  insecure: true
transport:
  type: udp
  udp:
    hopInterval: 120s
quic:
  initStreamReceiveWindow: 15400000
  initConnReceiveWindow: 38500000
  maxConnReceiveWindow: 77000000
  maxStreamReceiveWindow: 30800000
  keepAlivePeriod: 60s
bandwidth:
  download: 250mbps
  upload: 30mbps
fastOpen: true
socks5:
  listen: 127.0.0.1:20808
↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑COPY↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ 

📱 4. [Clash.Mini/ClashX.Meta/Clash.Meta for Android/Clash.verge/openclash] ClashMeta configuration file location: ./Hy2-test-ClashMeta.yaml  

✅ Configuration generation completed!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Configuration modified successfully 
root@localhost:/opt/test# hihy 14
-> 14) View real-time logs 
2025-01-07T14:53:16Z    INFO    server mode
2025-01-07T14:53:16Z    INFO    traffic stats server up and running     {"listen": "127.0.0.1:19215"}
2025-01-07T14:53:16Z    INFO    masquerade HTTPS server up and running  {"listen": ":43956"}
2025-01-07T14:53:16Z    INFO    server up and running   {"listen": ":43956"}
^C
root@localhost:/opt/test# hihy 13
-> 13) View Hysteria statistics 
=========== Hysteria Server Status ===========
【Traffic Statistics】 

【Online Users】 

【Active Connections】 
No active connections currently

</blockcode></pre>

</details>

## 4. Todo

**If you have good feature suggestions, please open an issue to propose them. PRs are welcome to add to the Todo list or fix my poor code!**

**My hobby is writing bugs （￣▽￣）~**

![img](imgs/gugugu.gif)

* [ ] Multi-user management, including kicking users offline, adding new users, etc.

## 5. Conclusion

Hysteria2 performs excellently in high-latency, high-packet-loss network environments, thanks to its custom aggressive congestion control algorithm.

This repository contributes to research in such harsh network environments by providing researchers with a convenient way to configure Hysteria2. In principle, all features provided by Hysteria2 are supported with highly customizable configurations.

If you find this helpful for learning shell scripting, please give this repository a small ⭐ to help more people discover it.

**No donations or advertising sponsorships are accepted. Please do not waste issue exposure opportunities.**

![img](./imgs/stickerpack.png)

## 6. Acknowledgments

[@apernet/hysteria](https://github.com/HyNetwork/hysteria)

[@2dust/v2rayN](https://github.com/2dust/v2rayN)

[@MetaCubeX/Clash.Meta](https://github.com/MetaCubeX/Clash.Meta)

[@fscarmen/warp](https://gitlab.com/fscarmen/warp)

---
