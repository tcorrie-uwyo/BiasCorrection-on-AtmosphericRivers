#!/bin/sh
# Make sure you have the right path to DetectBlobs pointed and activate an environment with TempestExtremes installed before running this .sh script!

/glade/work/tcorrie/conda-envs/TempestEnv/bin/DetectBlobs --in_data_list input_files_squeezed.txt --out_list output_files.txt --thresholdcmd "_LAPLACIAN{8,10}(_VECMAG(ivtx,ivty)),<=,-20000,0" --minlat 31.5 --geofiltercmd "area,>=,4e5km2" --lonname lon --latname lat --tagvar ARmask --regional