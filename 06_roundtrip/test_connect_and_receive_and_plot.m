%%% test connect_to_optotrak_sampling_server.m

import java.net.ServerSocket
import java.net.Socket
import java.io.*


%% connect to optotrak server
[in_socket, in_stream, d_in_stream, client_socket, out_socket, out_stream, d_out_stream] = ...
    connect_to_optotrak_sampling_server(50, 2010, '172.29.7.127', 2009);

%% start receiving samples
marker_1 = 1;
marker_2 = 2;
marker_3 = 3;
marker_4 = 7;
receive_time = 40; % for how much time should we receive samples
request_code = 'request'; % write this to stream in order to request a sample
stop_code = 'stopCollection'; % write this to stop the Collection on the server
samples = []; % no preallocation here yet
loop_times = [];
i = 0; % iterator for sample nr
 
% for plot
figure(2);
hold on;
x_bound = [-500 1300];
y_bound = [-1000 300];
z_bound = [-700 700];

% start loop!
try
    start_tic = tic;
    d_out_stream.writeUTF(request_code); % request a sample
    while toc(start_tic)<receive_time
        loop_tic = tic;
        [data_available, sample_data] = receive_from_optotrak_sampling_server(in_stream, d_in_stream);
        if data_available == 1
            i = i+1;
%             disp('sample data received');
%             disp(sample_data);
            samples(i, :) = sample_data;
            % plot here, given we have 3 markers
            clf;
            subplot(1,2,1);
            plot3( sample_data(3+3*marker_1), sample_data(1+3*marker_1), sample_data(2+3*marker_1), '.', ...
                  sample_data(3+3*marker_2), sample_data(1+3*marker_2), sample_data(2+3*marker_2), '.', ...
                  sample_data(3+3*marker_3), sample_data(1+3*marker_3), sample_data(2+3*marker_3), '.', ...
                  sample_data(3+3*marker_4), sample_data(1+3*marker_4), sample_data(2+3*marker_4), '.');
            xlim(x_bound);
            ylim(y_bound);
            zlim(z_bound);
            subplot(1,2,2);
            plot3( samples(:,3+3*marker_1), samples(:,1+3*marker_1), samples(:,2+3*marker_1), '.', ...
                  samples(:,3+3*marker_2), samples(:,1+3*marker_2), samples(:,2+3*marker_2), '.', ...
                  samples(:,3+3*marker_3), samples(:,1+3*marker_3), samples(:,2+3*marker_3), '.', ...
                  samples(:,3+3*marker_4), samples(:,1+3*marker_4), samples(:,2+3*marker_4), '.');
            xlim(x_bound);
            ylim(y_bound);
            zlim(z_bound);
            drawnow;
            % request new sample
            d_out_stream.writeUTF(request_code); % request another sample
        end
        loop_times = [loop_times toc(loop_tic)];
    end
    d_out_stream.writeUTF(stop_code); % request to terminate the sampling
catch IT
    if ~isempty(in_socket)
        in_socket.close;
    end
    if ~isempty(out_socket)
        d_out_stream.writeUTF(stop_code); % request to terminate the sampling
        out_socket.close;
    end
    if ~isempty(client_socket)
        client_socket.close;
    end
    rethrow(IT);
end

%% shutdown routines
pause(4.0);

if ~isempty(in_socket)
    in_socket.close;
end
if ~isempty(client_socket)
    client_socket.close;
end
if ~isempty(out_socket)
    out_socket.close;
end

disp('demo ended');

figure(3);
plot(loop_times);


