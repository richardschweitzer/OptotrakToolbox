%%% test connect_to_optotrak_sampling_server.m
%%% here we are interested in timing and how fast we can gather samples.

import java.net.ServerSocket
import java.net.Socket
import java.io.*


%% connect to optotrak server
[in_socket, in_stream, d_in_stream, client_socket, out_socket, out_stream, d_out_stream] = ...
    connect_to_optotrak_sampling_server(20, 2010, '172.29.7.127', 2009);

%% start receiving samples
receive_time = 10; % for how much time should we receive samples
request_code = 'request'; % write this to stream in order to request a sample
stop_code = 'stopCollection'; % write this to stop the Collection on the server
samples = []; % no preallocation here yet
times = [];
i = 0; % iterator for sample nr

% start loop!
try
    start_tic = tic;
    d_out_stream.writeUTF(request_code); % request a sample
    request_receive_tic = tic;
    while toc(start_tic) < receive_time
        receive_tic = tic;
        [data_available, sample_data, bytes, dur1, dur2, dur3] = receive_from_optotrak_sampling_server(in_stream, d_in_stream);
        receive_dur = toc(receive_tic);
        if data_available == 1
            i = i+1;
            samples(i, :) = sample_data;
            times(i, 6) = dur3;
            times(i, 5) = dur2;
            times(i, 4) = dur1;
            times(i, 3) = receive_dur;
            times(i, 2) = bytes;
            times(i, 1) = toc(request_receive_tic);
            
            % request another sample
            d_out_stream.writeUTF(request_code); 
            request_receive_tic = tic;
        end
    end
    d_out_stream.writeUTF(stop_code); % request to terminate the sampling
catch %IT
    if ~isempty(in_socket)
        in_socket.close;
    end
    if ~isempty(client_socket)
        client_socket.close;
    end
    if ~isempty(out_socket)
        out_socket.close;
    end
    %rethrow(IT);
end

%% shutdown routines
pause(1.0);

if ~isempty(in_socket)
    in_socket.close;
end
if ~isempty(client_socket)
    client_socket.close;
end
if ~isempty(out_socket)
    out_socket.close;
end

disp('all worked nicely');
plot(times(:,1), '.');
mean(times)