unique template metaconfig/slurm/cgroups;

include 'metaconfig/slurm/schema';

bind "/software/components/metaconfig/services/{/etc/slurm/cgroups.conf}/contents" = slurm_cgroups_conf;

prefix "/software/components/metaconfig/services/{/etc/slurm/cgroups.conf}";
"owner" = "root";
"group" = "root";
"mode" = 0644;
"module" = "slurm/dbd";
