# A kubernetes master (the one that controls the minions)
class kubernetes::master(
    $api_address        = '0.0.0.0',
    $api_port           = '8080',
    $kubelet_port       = '10250',
    $etcd_host          = '127.0.0.1',
    $etcd_port          = '4001',
    $service_net        = '10.100.0.0/16',
    $admission_control  = 'NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota',
    $manage_firewall    = true,
){
    class { 'selinux':
        mode    => 'permissive',
    }

    package { 'etcd':
        ensure => 'installed',
    }
    package { 'kubernetes':
        ensure => 'installed',
    }
    package { 'flannel':
        ensure => 'installed',
    }
    
    augeas { '/etc/sysconfig/flanneld':
        lens    => 'Shellvars.lns',
        incl    => '/etc/sysconfig/flanneld',
        notify  => Service['flanneld'],
        changes => [
            "set FLANNEL_ETCD 'http://127.0.0.1:${etcd_port}'",
        ],
        require => Package['flannel'],
    }
    
    augeas { '/etc/etcd/etcd.conf':
        lens    => 'Shellvars.lns',
        incl    => '/etc/etcd/etcd.conf',
        notify  => Service['etcd'],
        changes => [
            "set ETCD_NAME 'default'",
            "set ETCD_DATA_DIR '/var/lib/etcd/default.etcd'",
            "set ETCD_LISTEN_CLIENT_URLS 'http://0.0.0.0:${etcd_port}'",
            "set ETCD_ADVERTISE_CLIENT_URLS 'http://${::ipaddress}:${etcd_port}'",
        ],
        require => Package['etcd'],
    }

    augeas { '/etc/kubernetes/apiserver':
        lens    => 'Shellvars.lns',
        incl    => '/etc/kubernetes/apiserver',
        notify  => [
            Service['kube-apiserver'],
        ],
        changes => [
            "set KUBE_API_ADDRESS '--address=${api_address}'",
            "set KUBE_API_PORT '--port=${api_port}'",
            "set KUBELET_PORT '--kubelet_port=${kubelet_port}'",
            "set KUBE_ETCD_SERVERS '--etcd_servers=http://${etcd_host}:${etcd_port}'",
            "set KUBE_SERVICE_ADDRESSES '--service_cluster_ip_range=${service_net}'",
            "set KUBE_ADMISSION_CONTROL '--admission_control=${admission_control}'",
            "set KUBE_MASTER '--master=http://127.0.0.1:${api_port}'",
            "set KUBE_API_ARGS '--secure-port=4433'",
        ],
        require => Package['kubernetes'],
    }

    augeas { '/etc/kubernetes/controller-manager':
        lens    => 'Shellvars.lns',
        incl    => '/etc/kubernetes/controller-manager',
        notify  => [
            Service['kube-controller-manager'],
        ],
        changes => [
            "set KUBE_CONTROLLER_MANAGER_ARGS '\"--root-ca-file=/var/run/kubernetes/apiserver.crt --service-account-private-key-file=/var/run/kubernetes/apiserver.key\"'",
        ],
        require => Package['kubernetes'],
    }

    exec { 'store network config':
        command => '/usr/bin/etcdctl set /coreos.com/network/config \'{"Network":"10.244.0.0/16", "Backend": {"Type": "vxlan"}}\'',
        unless  => '/usr/bin/etcdctl get /coreos.com/network/config',
        require => Service['etcd'],
    }

    service { 'etcd':
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        require    => Package['etcd'],
    }

    service { ['kube-controller-manager', 'kube-scheduler']:
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        require    => [
            Package['kubernetes'],
            Service['etcd'],
            Service['kube-apiserver'],
        ],
    }

    service { 'kube-apiserver':
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        require    => [
            Package['kubernetes'],
            Service['etcd'],
        ],
    }

    service { 'flanneld':
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        require    => [
            Package['flannel'],
            Service['etcd'],
        ],
    }

    if $manage_firewall {
        service { 'firewalld':
            ensure => 'stopped',
            enable => false,
            notify => [
                Service['kube-proxy'],
            ],
        }

        firewall { "${api_port} kube-apiserver":
            port   => $api_port,
            proto  => 'tcp',
            action => 'accept',
        }

        firewall { "${etcd_port} etcd":
            port   => $etcd_port,
            proto  => 'tcp',
            action => 'accept',
        }
    }

    file { '/etc/kubernetes/addons':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    #kubernetes::addon { 'grafana-service': }
    #kubernetes::addon { 'heapster-controller': }
    #kubernetes::addon { 'heapster-service': }
    #kubernetes::addon { 'influxdb-grafana-controller': }
    #kubernetes::addon { 'influxdb-service': }
    #kubernetes::addon { 'kube-ui-controller': }
    #kubernetes::addon { 'kube-ui-service': }
    #kubernetes::addon { 'skydns-controller': }
    #kubernetes::addon { 'skydns-service': }
}
