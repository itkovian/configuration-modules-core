object template config;

include 'metaconfig/slurm/config';

prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents/control";

"ControlMachine" = 'master.example.com';
#ControlAddr = ;
#BackupController = ;
#BackupAddr = ;
"AuthType" = "munge";
"CryptoType" = "munge";
"DisableRootJobs" = true;
"EnforcePartLimits" = false;
#Epilog=
#EpilogSlurmctld=
"FirstJobId" = 1;
"MaxJobId" = 999999999;
#GresTypes=
"GroupUpdateForce" = 0;
"GroupUpdateTime" = 600;
"JobCheckpointDir" = "/var/spool/slurm/checkpoint";
#JobCredentialPrivateKey=
#JobCredentialPublicCertificate=
#JobFileAppend=0
#JobRequeue=1
"JobSubmitPlugins" = "lua";
#KillOnBadExit=0
#LaunchType=launch/slurm
#Licenses=foo*4,bar
"MailProg" = "/bin/mail";
"MaxJobCount" = 5000;
"MaxStepCount" = 40000;
"MaxTasksPerNode" = 128;
"MpiDefault" = "none";
#MpiParams=ports=#-#
#"PluginDir" = "/etc/slurm";
#PlugStackConfig=
"PrivateData" = list("jobs", "accounts", "nodes", "reservations", "usage");
"ProctrackType" = "cgroup";
#Prolog=
#PrologFlags=
#PrologSlurmctld=
#PropagatePrioProcess=0;
#PropagateResourceLimits=
#PropagateResourceLimitsExcept=
#RebootProgram=
"ReturnToService" = 1;
#SallocDefaultCommand=


prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents/process";

"SlurmctldPidFile" = "/var/run/slurmctld.pid";
"SlurmctldPort" = 6817;
"SlurmdPidFile" = "/var/run/slurmd.pid";
"SlurmdPort" = 6818;
"SlurmdSpoolDir" = "/var/spool/slurm/slurmd";
"SlurmUser" = "slurm";
#SlurmdUser=root
#SrunEpilog=
#SrunProlog=
"StateSaveLocation" = "/var/spool/slurm";
"SwitchType" = "none";
#TaskEpilog=
"TaskPlugin" = list("affinity" , "cgroup");
"TaskPluginParam" = dict("sched", true);
#TaskProlog=
#TopologyPlugin=topology/tree
#TmpFS=/tmp
#TrackWCKey=no
#TreeWidth=
#UnkillableStepProgram=
#UsePAM=0


prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents/timers";

#BatchStartTimeout=10
#CompleteWait=0
#EpilogMsgTime=2000
#GetEnvTimeout=2
#HealthCheckInterval=0
#HealthCheckProgram=
"InactiveLimit" = 0;
"KillWait" = 30;
#MessageTimeout=10
#ResvOverRun=0
"MinJobAge" = 300;
#OverTimeLimit=0
"SlurmctldTimeout" = 120;
"SlurmdTimeout" = 300;
#UnkillableStepTimeout=60
#VSizeFactor=0
"Waittime" = 0;


prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents/scheduling";

"DefMemPerCPU" = 123;
"FastSchedule" = 1;
"MaxMemPerNode" = 345;
#SchedulerTimeSlice = 30;
"SchedulerType" = "backfill";
"SchedulerParameters" = dict(
    "default_queue_depth", 128,
    "bf_max_job_test", 1024,
    "bf_continue", true,
    "bf_window", 4320,
    );
"SelectType" = "cons_res";
"SelectTypeParameters" = dict("CR_Core_Memory", true);

prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents/priority";

"PriorityFlags" = list("FAIR_TREE");
"PriorityType" = "multifactor";
"PriorityDecayHalfLife" = 7*24*60;
"PriorityCalcPeriod" = 5;
"PriorityFavorSmall" = false;
"PriorityMaxAge" = 28*24*60;
#PriorityUsageResetPeriod=
"PriorityWeightAge" = 5000;
"PriorityWeightFairshare" = 7000;
"PriorityWeightJobSize" = 2500;
#PriorityWeightPartition=
#PriorityWeightQOS=


prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents/accounting";

"AccountingStorageEnforce" = list("accounting");
"AccountingStorageHost" = 'slurmdb.example.org';
#AccountingStorageLoc = "/var/spool/slurm/job_accounting.log";"
#AccountingStoragePass=
#AccountingStoragePort=
"AccountingStorageType" = "slurmdbd";
#AccountingStorageUser=
"AccountingStoreJobComment" = true;
"ClusterName" = "thecluster";
#DebugFlags=
#JobCompHost=
"JobCompLoc" = "/var/spool/slurm/job_completions.log";
#JobCompPass=
#JobCompPort=
"JobCompType" = "filetxt";
#JobCompUser=
#JobContainerType=job_container/none
"JobAcctGatherFrequency" = 30;
"JobAcctGatherType" = "cgroup";


prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents/logging";

"SlurmctldDebug" = 3;
"SlurmctldLogFile" = "/var/log/slurmctld";
"SlurmdDebug" = 3;
"SlurmdLogFile" = "/var/log/slurmd";
#SlurmdLogFile=
#SlurmSchedLogFile=
#SlurmSchedLogLevel=


#prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents/power";
#SuspendProgram=
#ResumeProgram=
#SuspendTimeout=
#ResumeTimeout=
#ResumeRate=
#SuspendExcNodes=
#SuspendExcParts=
#SuspendRate=
#SuspendTime=


prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents/nodes/DEFAULT";
"CPUs" = 4;
"RealMemory" = 3500;
"Sockets" = 4;
"CoresPerSocket" = 1;
"ThreadsPerCore" = 1;
"State" = "UNKNOWN";

prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents/nodes/compute";
"NodeName" = list("node1", "node2");
"CPUs" = 8;
"RealMemory" = 3500;
"Sockets" = 4;
"CoresPerSocket" = 1;
"ThreadsPerCore" = 2;
"State" = "UP";

prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents/partitions/thepartition";
"Nodes" = list('ALL');
"Default" = true;
"MaxTime" = 3*24*60;
"State" = "UP";
"DisableRootJobs" = true;

prefix "/software/components/metaconfig/services/{/etc/slurm/slurm.conf}/contents/partitions/thepartition-debug";
"Nodes" = list('node2801','node2802');
"MaxTime" = 3*24*60;
"State" = "DOWN";
"DisableRootJobs" = false;
