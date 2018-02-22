object template cgroups;

include 'metaconfig/slurm/cgroups';

prefix "/software/components/metaconfig/services/{/etc/slurm/cgroups.conf}/contents";
'CgroupAutomount' = true;

'ConstrainCores' = true;
'ConstrainRAMSpace' = true;
'ConstrainSwapSpace' = true;

'AllowedSwapSpace' = 10;

'TaskAffinity' = true;
