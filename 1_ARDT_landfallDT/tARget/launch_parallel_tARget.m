function launch_parallel_tARget

    flist = dir('/glade/derecho/scratch/tcorrie/regrids/temptARget/ivt.daily.*.*_regridded.*.nc');

    parfor idx = 1:numel(flist)
        st = split(flist(idx).name, '.');
        model = st{3};
        member = st{4};
        year = st{6};
        
        feval(@run_tARget, model, member, year);
    end
end
