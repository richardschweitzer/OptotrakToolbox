% test server--client timing: SERVER

import java.net.ServerSocket
import java.net.Socket
import java.io.*

%%% parameters %%%
% general
duration = 10; % in seconds
number_of_retries = 200;
% server data. This is the server
this_ip = '172.29.7.127';
output_port_server = 2700; % the output port of the server must be the input port of the client
server_socket  = [];
output_socket_server  = [];
% client data
client_ip = '172.29.10.15'; % qumisha
%client_ip = '172.29.10.14'; % vandemar
input_port_server = 2701; % the input port of the server must be the output port of the client
input_socket_server  = [];


message = 'hello, I am the server';


%% 1. Setup connections %%
% http://iheartmatlab.blogspot.de/2008/08/tcpip-socket-communications-in-matlab.html
retry = 0;
connected_output = 0;
connected_input = 0;

% start trying to connect
while connected_output == 0 || connected_input == 0

        retry = retry + 1;
        
        if ((number_of_retries > 0) && (retry > number_of_retries))
                fprintf(1, 'Too many retries\n');
                break;
        end

        try
            %% setup output stream from server to client (we are the server)
            if connected_output == 0
                fprintf(1, ['Try %d waiting for client to connect to this ' ...
                            'server on port : %d\n'], retry, output_port_server);
                % wait for 1 second for client to connect server socket
                server_socket = ServerSocket(output_port_server);
                server_socket.setSoTimeout(1000);
                % make output socket when server socket is accepted by client
                output_socket_server = server_socket.accept;
                fprintf(1, 'Output Connection established on Server: Server to Client\n');
                % make outputStream
                output_stream_server   = output_socket_server.getOutputStream;
                d_output_stream_server = DataOutputStream(output_stream_server);
                % outputStream created
                connected_output = 1;
            end
            
            %% setup input stream from client to server (we are the server)
            if connected_input == 0
                fprintf(1, 'Retry %d connecting to client %s:%d\n', ...
                        retry, client_ip, input_port_server);
                % throws if unable to connect
                input_socket_server = Socket(client_ip, input_port_server);
                % get a buffered data input stream from the socket
                input_stream_server   = input_socket_server.getInputStream;
                d_input_stream_server = DataInputStream(input_stream_server);
                % 
                fprintf(1, 'Input Connection established on Server: Client to Server\n');           
                connected_input = 1;
            end
            
        catch %ME
            
            if ~isempty(server_socket)
                server_socket.close
            end
            if ~isempty(output_socket_server)
                output_socket_server.close
            end
            if ~isempty(input_socket_server)
                input_socket_server.close;
            end
            % pause before retrying
            pause(1);
            %rethrow(ME);
        end
end

% pause for a second
pause(1);



%% 2. Wait for Input from Client and send some data back %%%
fprintf(1, 'Start receiving data and sending it back...\n');           
size_of_array = 50;
i = 1;
times_server = [];
try
    while 1
        bytes_available = input_stream_server.available;
        if bytes_available > 0
            %bytes_available
            % read
            message_from_client = d_input_stream_server.readUTF;
            %disp('Message from client received: ');
            %disp(message_from_client);
            tic;
            % write
            message = mat2str(randn(1, size_of_array));
            d_output_stream_server.writeUTF(message);
            %disp('Response from Server sent to Client: ');
            %disp(message);
            times_server(i) = toc;
            i = i+1;
            if strcmp(message_from_client, ';')
                break
            end
        end
    end
catch
    if ~isempty(server_socket)
        server_socket.close
    end
    if ~isempty(output_socket_server)
        output_socket_server.close
    end
    if ~isempty(input_socket_server)
        input_socket_server.close;
    end
end


%% 3. Close connection %%%
% clean up
if ~isempty(server_socket)
    server_socket.close
end
if ~isempty(output_socket_server)
    output_socket_server.close
end
if ~isempty(input_socket_server)
    input_socket_server.close;
end
% message
fprintf(1, 'All went well.\n');           




