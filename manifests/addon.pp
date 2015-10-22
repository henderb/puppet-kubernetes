# A kubernetes addon
define kubernetes::addon(
    $filename           = $title,
    $template           = $title,
    $master_host        = 'kube-master.example.com',
    $master_port        = '8080',
    $service_net_prefix = '10.100',
    $cluster_domain     = 'cluster.local',
){
    file { "/etc/kubernetes/addons/${filename}.yaml":
        ensure  => 'file',
        content => template("kubernetes/addons/${template}.yaml.erb"),
        owner   => 'root',
        group   => 'root',
        mode    => '0640',
    }
}
