> # 🤫 VPN
>
> Easy way to up your virtual private network.

## 💡 Idea

Nothing special, just to find a way to set up and run a personal VPN quickly.

## 🏆 Motivation

Internet censorship has been increasing steadily for the last decade. Needs more?
[10 reasons why you need a VPN](https://www.techradar.com/news/10-reasons-why-you-need-a-vpn).

## 🤼‍♂️ How to

```bash
$ export VPN_NAME=gateway   # your server name, any way you like
$ export VPN_HOST=127.0.0.1 # your server ip

$ cat ansible/hosts.tpl.ini \
  | sed "s/{{.Name}}/${VPN_NAME}/g" \
  | sed "s/{{.Host}}/${VPN_HOST}/g" \
  > ansible/hosts

$ make
```

### Recommended providers

| Provider           | Availability | IPv6 | Price      |
|:-------------------|:-------------|:----:|-----------:|
| [DigitalOcean][do] | worldwide    |  ✓   | $5/month   |
| [Linode][linode]   | worldwide    |  ✓   | $5/month   |
| [Vultr][vultr]     | worldwide    |  ✓   | $2.5/month |

<small>☝️ all links are referral</small>

## 🧩 Installation

```bash
$ git clone git@github.com:octomation/vpn.git && cd vpn
```

## 👨‍🔬 Research

### Articles

At Serverwise

- [ ] [How To Install OpenVPN On Ubuntu 18.04](https://blog.ssdnodes.com/blog/install-openvpn-ubuntu-18-04-tutorial/)
- [x] [Outline VPN: How to install it on your server](https://blog.ssdnodes.com/blog/outline-vpn-tutorial-vps/).
- [ ] [Streisand VPN: How To Install And Configure](https://blog.ssdnodes.com/blog/streisand-vpn-tutorial/).

At DigitalOcean

- [ ] [How To Set Up and Configure an OpenVPN Server on Ubuntu 20.04](https://www.digitalocean.com/community/tutorials/how-to-set-up-and-configure-an-openvpn-server-on-ubuntu-20-04).

### Sources

- [ ] [Jigsaw-Code/outline-server](https://github.com/Jigsaw-Code/outline-server)
  - [x] [install_server.sh](research/Jigsaw-Code/outline-server/src/server_manager/install_scripts/install_server.sh)
- [ ] [angristan/openvpn-install](https://github.com/angristan/openvpn-install)
- [ ] [angristan/wireguard-install](https://github.com/angristan/wireguard-install)
- [ ] [kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn)
- [ ] [Nyr/openvpn-install](https://github.com/Nyr/openvpn-install)
- [ ] [Nyr/wireguard-install](https://github.com/Nyr/wireguard-install)
- [ ] [StreisandEffect/streisand](https://github.com/StreisandEffect/streisand)
- [ ] [timurb/ansible-digitalocean-vpn](https://github.com/timurb/ansible-digitalocean-vpn)

### Toolset

- [Ansible is Simple IT Automation](https://www.ansible.com/).
  - [Ansible at GitHub](https://github.com/ansible).
- [Empowering App Development for Developers | Docker](https://www.docker.com/).
  - [Docker at GitHub](https://github.com/docker).
- [Outline VPN - Access to the free and open internet](https://www.getoutline.org/).
  - [Outline at GitHub](https://github.com/Jigsaw-Code/?q=outline).
- Docker images
  - [containrrr/watchtower at Docker Hub](https://hub.docker.com/r/containrrr/watchtower).
  - [outline/shadowbox at Quay.io](https://quay.io/repository/outline/shadowbox).

<p align="right">made with ❤️ for everyone</p>

[do]:     http://bit.ly/vps-do-ref
[linode]: http://bit.ly/vps-linode-ref
[vultr]:  http://bit.ly/vps-vultr-ref
