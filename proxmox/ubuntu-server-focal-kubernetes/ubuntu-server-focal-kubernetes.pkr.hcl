# Ubuntu Server Focal Kubernetes
# ---
# Packer Template to create an Ubuntu Server (Focal) with Kubernetes on Proxmox

# Variable Definitions
variable "proxmox_api_url" {
    type = string
}

variable "proxmox_api_token_id" {
    type = string
}

variable "proxmox_api_token_secret" {
    type = string
    sensitive = true
}

# Resource Definiation for the VM Template
source "proxmox" "ubuntu-server-focal-kubernetes" {
 
    # Proxmox Connection Settings
    proxmox_url = "${var.proxmox_api_url}"
    username = "${var.proxmox_api_token_id}"
    token = "${var.proxmox_api_token_secret}"
    # (Optional) Skip TLS Verification
    insecure_skip_tls_verify = true
    
    # VM General Settings
    node = "pve"
    vm_id = "9020"
    vm_name = "ubuntu-server-focal-kubernetes"
    template_description = "Ubuntu Server Focal Image with Kubernetes pre-installed"

    # VM OS Settings
    # (Option 1) Local ISO File
    iso_file = "datastore:iso/ubuntu-20.04.5-live-server-amd64.iso"
    # - or -
    # (Option 2) Download ISO
    # iso_url = "https://releases.ubuntu.com/20.04/ubuntu-20.04.3-live-server-amd64.iso"
    # iso_checksum = "f8e3086f3cea0fb3fefb29937ab5ed9d19e767079633960ccb50e76153effc98"
    iso_storage_pool = "datastore"
    unmount_iso = true

    # VM System Settings
    qemu_agent = true

    # VM Hard Disk Settings
    scsi_controller = "virtio-scsi-pci"

    disks {
        disk_size = "20G"
        format = "qcow2"
        storage_pool = "datastore"
        storage_pool_type = "lvm"
        type = "virtio"
    }

    # VM CPU Settings
    cores = "4"
    
    # VM Memory Settings
    memory = "4096" 

    # VM Network Settings
    network_adapters {
        model = "virtio"
        bridge = "vmbr0"
        firewall = "false"
    } 

    # VM Cloud-Init Settings
    cloud_init = true
    cloud_init_storage_pool = "datastore"

    # PACKER Boot Commands
    boot_command = [
        "<esc><wait><esc><wait>",
        "<3><wait>",
        "<f6><wait><esc><wait>",
        "<f6><wait><esc><wait>",
        "<bs><bs><bs><bs><bs>",
        "autoinstall ds=nocloud-net;s=http://10.10.100.111:8802/ ",
        "--- <enter>"
 #       "<esc><wait><3><wait>",
 #       "<f6><wait><esc><wait>",
 #       "<bs><bs><bs><bs><bs>",
 #       "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
 #       "autoinstall ds=nocloud-net;s=http://10.10.100.111:8802/ ",
 #       "--- <enter>"
 #       "<esc><wait><esc><wait><esc><wait>"
    ]
    boot = "c"
    boot_wait = "10s"

    # PACKER Autoinstall Settings
    http_directory = "http" 
    # (Optional) Bind IP Address and Port
    # http_bind_address = "10.10.100.111"
    http_port_min = 8802
    http_port_max = 8802

    ssh_username = "leonardo"

    # (Option 1) Add your Password here
    # ssh_password = "123mudar!"
    # - or -
    # (Option 2) Add your Private SSH KEY file here
    ssh_private_key_file = "~/.ssh/id_rsa"

    # Raise the timeout, when installation takes longer
    ssh_timeout = "40m"
}

# Build Definition to create the VM Template
build {

    name = "ubuntu-server-focal-kubernetes"
    sources = ["source.proxmox.ubuntu-server-focal-kubernetes"]

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
    provisioner "shell" {
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge",
            "sudo apt -y clean",
            "sudo apt -y autoclean",
            "sudo cloud-init clean",
            "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
            "sudo sync"
        ]
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
    provisioner "file" {
        source = "files/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
    provisioner "shell" {
        inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
    }

    # Provisioning the VM Template with Docker Installation #4
    provisioner "shell" {
        inline = [
            "sudo apt update",
            "sudo apt upgrade -y"
        ]
    }

    # Provisioning the VM Template with Docker Installation #4
    provisioner "shell" {
        inline = [
            "sudo apt update",
            "sudo apt install -y gnupg2 software-properties-common apt-transport-https ca-certificates curl vim git wget",
            "sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
            "sudo echo \"deb https://apt.kubernetes.io/ kubernetes-xenial main\" | sudo tee /etc/apt/sources.list.d/kubernetes.list",
            #"sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg",
            #"echo \"deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main\" | sudo tee /etc/apt/sources.list.d/kubernetes.list",
            "sudo apt update",
            "sudo apt install -y kubelet kubeadm kubectl",
            "sudo apt-mark hold kubelet kubeadm kubectl"
        ]
    }

        # Provisioning the VM Template with Docker Installation #4
    provisioner "shell" {
        inline = [
            "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
            "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
            "sudo apt install containerd.io -y",
            #"sudo su -",
            #"mkdir -p /etc/containerd",
            #"containerd config default>/etc/containerd/config.toml",
            #"exit",
            "sudo systemctl restart containerd",
            "sudo systemctl enable containerd"
        ]
    }
}
