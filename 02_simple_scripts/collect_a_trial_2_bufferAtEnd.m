% Written by Jarrod Blinch, November 13th, 2010
% Available from motorbehaviour.wordpress.com
% NON-BLOCKING VERSION by RS

addpath('\\KASTORI\Users\sysop\Documents\Visual Studio 2015\Projects\Matlab_to_Optotrak\Debug')    
 
collection_num_markers_1 = 3;     		% optotrak
collection_num_markers_2 = 6; 
collection_frequency = 120;     		% Hz
collection_duration = 20;        		% s
buffer_time = 5;
total_frame_num = collection_frequency * collection_duration;
cam_filename = 'Aligned20160728';     % .cam file for sensor. % name of sensor: C3-04864

try
    [a b] = Matlab_to_Optotrak('TransputerLoadSystem', collection_num_markers_1, collection_num_markers_2, ...
        collection_frequency, collection_duration+buffer_time, cam_filename, 0);
    if (a ~= 0)
        error('TransputerLoadSystem died!');
        b
    end
    pause(1);
    [a b] = Matlab_to_Optotrak('OptotrakActivateMarkers'); %#ok<NASGU>
    if (a ~= 0)
        error('OptotrakActivateMarkers died!');
    end
    start_tic = tic;
    
    
    [a b] = Matlab_to_Optotrak('DataBufferInitializeFile', '', 'test_002.P01');
    
    
    
    % Array b will contain the current IRAD locations.
    tic;
    [a b] = Matlab_to_Optotrak('DataGetLatest3D');
    toc;
    display('IRED locations:');
    display(b(4:end));
    
    % create array for 3d data
    sample_length = length(b);
    save_here = zeros(total_frame_num, sample_length);
    time_save_here = zeros(2, total_frame_num);
    time_write_buffer = zeros(1, total_frame_num);
    
    
%     [a b] = Matlab_to_Optotrak('DataBufferStart');
    
    data_buffer_done = false;
    i = 1;
    sample = 1;
    Matlab_to_Optotrak('RequestLatest3D');
    while toc(start_tic)< collection_duration %(data_buffer_done == false) 
        % retrieve realtime data
        tic;
        %data_ready = Matlab_to_Optotrak('DataIsReady')
        %if data_ready ~=0
        [data_status, data] = Matlab_to_Optotrak('DataReceiveLatest3D');
        %end
        time_save_here(2, i) = toc;
        i = i+1;
        % request new frame
        if data_buffer_done == false
            if strcmp(data, 'DataNotReady') ~= 1 || data_status ~= -1
                save_here(sample,:) = data;
                sample = sample + 1;
%                 if i>10000 
%                     data_buffer_done = true; end;
%                 if mod(i, 300) == 0
%                     % write data to buffer
%                     tic;
%                     [a, b] = Matlab_to_Optotrak('DataBufferWriteData');
%                     if (a ~= 0)
%                         display('Warning: DataBufferWriteData died!');
%                     end
%                     if (b == 1)
%                         data_buffer_done = true;
%                     end
%                     time_save_here(1, i) = toc;
%                 end
                % request next data frame
                Matlab_to_Optotrak('RequestNext3D');
            end
        end

    end
    % get the last sample which is waiting
    pause(0.1);
    [a, b] = Matlab_to_Optotrak('DataReceiveLatest3D');
    save_here(sample,:) = b;
%     Matlab_to_Optotrak('OptotrakStopCollection');
    
    
    % now spool data
    tic;
    disp('Now DataBufferSpoolData...');
    [a b] = Matlab_to_Optotrak('DataBufferSpoolData');
    if (a ~= 0)
        display('Warning: DataBufferSpoolData died!');
    else
        disp('Done DataBufferSpoolData');
    end
    toc;
    
    % Convert the R and O files to C and V.
    [a b] = Matlab_to_Optotrak('FileConvert', '', 'test_002.P01');
    
    optotrak_array = open_ndi_bin_file('C#test_002.P01');
    
    
    
    [a b] = Matlab_to_Optotrak('OptotrakDeActivateMarkers'); %#ok<NASGU>
    if (a ~= 0)
        display('Warning: OptotrakDeActivateMarkers died!');
    end
    [a b] = Matlab_to_Optotrak('TransputerShutdownSystem');
    if (a ~= 0)
        display('Warning: TransputerShutdownSystem died!');
    end
    
     
    
    % plot
    plot(time_save_here(2, :), '.');
    
    % Release the Matlab_to_Optotrak.mexw32 file, which allows it
    % to be compiled in Visual C++ if needed.
    clear mex;
    
catch ME
    
    [a b] = Matlab_to_Optotrak('OptotrakDeActivateMarkers'); %#ok<NASGU>
    if (a ~= 0)
        display('Warning: OptotrakDeActivateMarkers died!');
    end
    [a b] = Matlab_to_Optotrak('TransputerShutdownSystem');
    if (a ~= 0)
        display('Warning: TransputerShutdownSystem died!');
    end
    
    % Release the Matlab_to_Optotrak.mexw32 file, which allows it
    % to be compiled in Visual C++ if needed.
    clear mex;
    
    rethrow(ME);
end
