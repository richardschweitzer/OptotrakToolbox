% test server--client timing: CLIENT

import java.net.ServerSocket
import java.net.Socket
import java.io.*

buffer_size = 1200;

%%% parameters.  %%%
% general
duration = 10; % in seconds
number_of_retries = 200;
n = 1000; % number of packages to send and receive

% client data. this is the CLIENT
this_ip = '172.29.10.15';
input_port_client = 2700; % the input port of the client must be the output port of the server
input_socket_client  = [];

% server data
server_ip = '172.29.7.127'; % kastori
%server_ip = '172.29.7.10'; % lenovo x200
output_port_client = 2701; % the output port of the client must be the input port of the server
client_socket  = [];
output_socket_client  = [];



message = 'hello, I am the client';


%%% 1. Setup connections %%%
% http://iheartmatlab.blogspot.de/2008/08/tcpip-socket-communications-in-matlab.html
retry = 0;
connected_input = 0;
connected_output = 0;

while connected_input == 0 || connected_output == 0
    
        retry = retry + 1;
        if ((number_of_retries > 0) && (retry > number_of_retries))
            fprintf(1, 'Too many retries\n');
            break;
        end
        
        try
            %% setup input stream from server to client (we are the client)
            if connected_input == 0
                fprintf(1, 'Retry %d connecting to server %s:%d\n', ...
                        retry, server_ip, input_port_client);
                % throws if unable to connect
                input_socket_client = Socket(server_ip, input_port_client);
                
                tcp_no_delay = input_socket_client.getTcpNoDelay;
                if ~tcp_no_delay
                    input_socket_client.setTcpNoDelay(1);
                end
                tcp_no_delay_new = input_socket_client.getTcpNoDelay;

                input_receive_buffer_size = input_socket_client.getReceiveBufferSize;
                input_socket_client.setReceiveBufferSize(buffer_size);
                input_receive_buffer_size_new = input_socket_client.getReceiveBufferSize;
                
                input_send_buffer_size = input_socket_client.getSendBufferSize;
                input_socket_client.setSendBufferSize(buffer_size);
                input_send_buffer_size_new = input_socket_client.getSendBufferSize;
                
                % get a buffered data input stream from the socket
                input_stream_client   = input_socket_client.getInputStream;
                d_input_stream_client = DataInputStream(input_stream_client);
                %
                fprintf(1, 'Input Connection established on Client: Server to Client\n');      
                connected_input = 1;
            end
                
            %% setup output stream from client to server (we are the client)
            if connected_output == 0
                fprintf(1, ['Try %d waiting for server to connect to this ' ...
                            'client on port : %d\n'], retry, output_port_client);
                % wait for 1 second for client to connect server socket
                client_socket = ServerSocket(output_port_client);
                % get output buffer size and set it to a new value
                output_receive_buffer_size = client_socket.getReceiveBufferSize;
                client_socket.setReceiveBufferSize(buffer_size);
                output_receive_buffer_size_new = client_socket.getReceiveBufferSize;

                client_socket.setSoTimeout(1000);
                % make output socket when server socket is accepted by server
                output_socket_client = client_socket.accept;
                fprintf(1, 'Output Connection established on Client: Client to Server\n');
                % make output stream
                output_stream_client   = output_socket_client.getOutputStream;
                d_output_stream_client = DataOutputStream(output_stream_client);
                % output stream created
                connected_output = 1;
            end
            
        catch %ME
            if ~isempty(input_socket_client) &&  connected_input==0
                input_socket_client.close;
            end
            if ~isempty(client_socket) && connected_output==0
                client_socket.close;
            end
            if ~isempty(output_socket_client) && connected_output==0
                output_socket_client.close;
            end
            % pause before retrying
            pause(1);
            %rethrow(ME);
        end
end

% pause for a second
pause(1);

%% 2. Send some data to server and wait for it to come back %%%
fprintf(1, 'Start sending and receiving data...\n');
times_client = zeros(3, n);
% send a message to server
try
    for i = 1:n
        %disp('Message to server: ');
        %disp(message);
        received_something = 0;
        tic;
        d_output_stream_client.writeUTF(message);
        d_output_stream_client.flush;
        times_client(1,i) = toc;
        client_tic = tic;
        % wait for its answer
        while received_something == 0 
            bytes_available = input_stream_client.available;
            if bytes_available > 0
                times_client(4,i) = bytes_available;
                tic;
                message_from_server = d_input_stream_client.readUTF;
                times_client(2,i) = toc;
                times_client(3,i) = toc(client_tic);
                %disp(times_client(i));
                %disp('Message from server: ');
                %disp(message_from_server);
                received_something = 1;
            end
        end
    end
    d_output_stream_client.writeUTF(';');
    
catch ME
    if ~isempty(input_socket_client)
        input_socket_client.close;
    end
    if ~isempty(client_socket)
        client_socket.close;
    end
    if ~isempty(output_socket_client)
        d_output_stream_client.writeUTF(';');
        output_socket_client.close;
    end
    rethrow(ME);
end

%% 3. Close connections %%%
% clean up
if ~isempty(input_socket_client)
    input_socket_client.close;
end
if ~isempty(client_socket)
    client_socket.close;
end
if ~isempty(output_socket_client)
    output_socket_client.close;
end
% display values
fprintf(1, 'All went well. Here some values.\n');
fprintf(1, ['Mean and standard deviation of transfer duration is: %f %f.\n'], mean(times_client(3, :)), std(times_client(3, :)));
plot(times_client(3, :), '.')



 