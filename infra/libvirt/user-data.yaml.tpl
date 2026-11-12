#cloud-config
# Szablon cloud-init dla węzła k3s na libvirt/KVM (odpowiednik trybu "plain" Limy:
# VM bez montowania katalogów hosta — scenariusz 1 daje tu roota, więc izolacja jest konieczna).
# Pola __HOSTNAME__ i __SSHKEY__ podstawia infra/libvirt/provision.sh.
hostname: __HOSTNAME__
fqdn: __HOSTNAME__
preserve_hostname: false

users:
  - name: krycy
    groups: [sudo]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - __SSHKEY__

ssh_pwauth: false
package_update: false
package_upgrade: false
# k3s sam ładuje overlay/br_netfilter; nic więcej nie instalujemy, żeby obraz był powtarzalny.
# IP węzła ustalamy z dzierżaw DHCP libvirta (--source lease), więc guest-agent nie jest wymagany.
