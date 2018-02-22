object template plugstack;

include 'metaconfig/slurm/plugstack';

prefix "/software/components/metaconfig/services/{/etc/slurm/plugstack.conf}/contents/plugins/0";
"path" = "/some/path";

prefix "/software/components/metaconfig/services/{/etc/slurm/plugstack.conf}/contents/plugins/1";
"path" = "/some/other/path";
"arguments" = dict(
    "woohoo", true,
    "hello", "world"
    );
"optional" = true;

prefix "/software/components/metaconfig/services/{/etc/slurm/plugstack.conf}/contents";
"includes/0/directory" = "/some/incl";
"includes/1/directory" = "/some/other/incl";
