unique template metaconfig/slurm/config;

include 'metaconfig/slurm/schema';

bind "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents" = slurm_conf;

prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}";
"owner" = "root";
"group" = "root";
"mode" = 0644;
"module" = "tiny";