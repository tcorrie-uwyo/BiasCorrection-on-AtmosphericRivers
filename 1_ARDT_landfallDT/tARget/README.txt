Order of Operations for running tARget:

1. data_timeslicing_and_stitching.ipynb
    - Only the cells up to creating the 40-year netcdf file are required.
2. pixelivtcalcs.ipynb
    - Even over a large dataset this shouldn't take too long.
3. run_tARget.m
    - If parallelization is desired, this isn't ran directly. But it does contain the structure/setup for tARget.
4. launch_parallel_tARget.m
    - Setting up the parallelization for run_tARget.m
5. submit_tARget_to_server.sh
    - This is what is submitted to the server to run. May take a while to clear the queue.



Other notebooks:
target.m (In case you want the stitching features)
target_shapeonly.m (Experimental without stitching features; unsure if this actually helps speed performance)
run_tARget_tests.ipynb (A notebook for running individual models or other unconventional time slices)