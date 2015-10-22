# A kubernetes minion node (the ones that run docker apps)
class kubernetes::minion(
    $master_host,
    $master_port        = '8080',
    $kubelet_hostname   = $::fqdn,
    $kubelet_args       = '',
    $kubelet_port       = '10250',
    $etcd_port          = '4001',
){
    class { 'selinux':
        mode    => 'permissive',
    }

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
        notify  => [
            Service['kube-proxy'],
            Service['kubelet'],
        ],
        changes => [
            "set KUBE_MASTER '--master=http://${master_host}:${master_port}'",
        ],
        require => Package['kubernetes'],
    }

    augeas { '/etc/kubernetes/kubelet':
        lens    => 'Shellvars.lns',
        incl    => '/etc/kubernetes/kubelet',
        notify  => Service['kubelet'],
        changes => [
            "set KUBELET_ADDRESS '--address=0.0.0.0'",
            "set KUBELET_PORT '--port=${kubelet_port}'",
            "set KUBELET_HOSTNAME '--hostname-override=${kubelet_hostname}'",
            "set KUBELET_API_SERVER '--api-servers=http://${master_host}:${master_port}'",
            "set KUBELET_ARGS '\"--cluster-dns=10.100.53.53 --cluster-domain=cluster.local ${kubelet_args}\"'",
        ],
    }

    service { 'firewalld':
        ensure => 'stopped',
        enable => false,
        notify => [
            Service['kube-proxy'],
            Service['kubelet'],
        ],
    }

    service { ['kube-proxy', 'kubelet', 'docker', 'flanneld']:
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        require    => [
            Package['kubernetes'],
            Package['flannel'],
        ],
    }

    service { 'docker':
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        require    => [
            Service['kubelet'],
        ],
    }
}
