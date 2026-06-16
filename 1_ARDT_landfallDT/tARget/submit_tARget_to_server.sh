#!/bin/bash

# This doesn't need to run on a batch node... we can simply schedule
# the parallel job via the login node

module purge
module load ncarenv/24.12
module load matlab
module list 

mkdir -p output

# Job parameters
# Note that the batch command will use an additional orchestration worker
# For more info on fields: https://www.mathworks.com/help/matlab-parallel-server/customize-behavior-of-sample-plugin-scripts.html

MPS_num_workers=8
MPS_threads_per_worker=2
MPSNODES=16
MPSTASKS=16
MPS_memory_per_worker=16GB
MPSACCOUNT=WYOM0169
MPSQUEUE=main

# Use here-doc to send submit script to Matlab
SECONDS=0

matlab -nodesktop -nosplash << EOF
% Add cluster profile if not already present
if ~any(strcmp(parallel.clusterProfiles, 'ncar_mps'))
    ncar_mps = parallel.importProfile('/glade/u/apps/opt/matlab/parallel/ncar_mps.mlsettings');
end

% Start PBS cluster and submit job with custom number of workers
c = parcluster('ncar_mps');

% Matlab workers will equal nodes * tasks-per-node - 1
jNodes = '$MPSNODES';
jTasks = '$MPSTASKS';
jWorkers = str2num(jNodes) * str2num(jTasks) - 1;

c.ClusterMatlabRoot = getenv('NCAR_ROOT_MATLAB');
c.SubmitArguments = append('-A $MPSACCOUNT -q $MPSQUEUE -l select=', jNodes, ':ncpus=', jTasks, ':mpiprocs=', jTasks, ' -l walltime=12:00:00', ' -l job_priority=premium');
c.JobStorageLocation = append(getenv('PWD'), '/output');

% Output cluster settings
c

% Submit job to batch scheduler (PBS)
j = batch(c, @launch_parallel_tARget, 0, {}, 'pool', jWorkers);

% Wait for job to finish and get output
wait(j);
diary(j);
exit;
EOF

echo "Time elapsed = $SECONDS s"
