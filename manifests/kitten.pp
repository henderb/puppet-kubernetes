# A server with kube-proxy and flannel routing
class kubernetes::kitten(
    $master_host,
    $master_port        = '8080',
    $kubelet_hostname   = $::fqdn,
    $kubelet_args       = '',
    $kubelet_port       = '10250',
    $etcd_port          = '4001',
){

    package { 'flannel':
        ensure => 'installed',
    }
    package { 'kubernetes':
        ensure => 'installed',
    }
    
    augeas { '/etc/sysconfig/flanneld':
        lens    => 'Shellvars.lns',
        incl    => '/etc/sysconfig/flanneld',
        notify  => Service['flanneld'],
        changes => [
            "set FLANNEL_ETCD 'http://${master_host}:${etcd_port}'",
        ],
        require => Package['flannel'],
    }

    augeas { '/etc/kubernetes/config':
        lens    => 'Shellvars.lns',
        incl    => '/etc/kubernetes/config',
        notify  => Service['kube-proxy'],
        changes => [
            "set KUBE_MASTER '--master=http://${master_host}:${master_port}'",
        ],
        require => Package['kubernetes'],
    }

    service { ['kube-proxy', 'flanneld']:
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        require    => [
            Package['kubernetes'],
            Package['flannel'],
        ],
    }
}
