unique template metaconfig/slurm/plugstack;

include 'metaconfig/slurm/schema';

bind "/software/components/metaconfig/services/{/etc/slurm/plugstack.conf}/contents" = slurm_plugstack_conf;

prefix "/software/components/metaconfig/services/{/etc/slurm/plugstack.conf}";
"owner" = "root";
"group" = "root";
"mode" = 0644;
"module" = "slurm/plugstack";
