List of Service Providers Restricting UDP [Updated 2025/01/07]
The reason behind this is that a small number of IDC providers fear being overwhelmed by DDoS attacks, leading to the restrictions outlined below. Rest assured, most service providers perform normally with Hysteria2. The providers listed below have a history of being unusable, but whether they are currently usable should be tested by yourself (providers not listed are assumed to be usable). This list is for reference only:

Log behavior: [error:timeout: no recent network activity] Failed to initialize client

DigitalOcean: Sometimes usable, sometimes not. Its firewall rules are unpredictable, and its Floating IP has even stricter restrictions.
Vultr: Behaves similarly to DigitalOcean.
AWS: When using EC2 instances with UDP modes like udp/wechat-video, AWS may flag it as an outbound UDP attack, resulting in a warning email. However, this issue has not been observed in actual use, possibly due to reduced false positives with the widespread adoption of HTTP/3.
RackNerd: Many users report that its Los Angeles region cannot use UDP-based protocols like udp/wechat-video.
