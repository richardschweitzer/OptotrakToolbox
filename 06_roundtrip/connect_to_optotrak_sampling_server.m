function [input_socket_client, input_stream_client, d_input_stream_client, ...
    client_socket, output_socket_client, output_stream_client, d_output_stream_client] = ...
    connect_to_optotrak_sampling_server(number_of_retries, input_port_client, server_ip, output_port_client)
    
    % this function connects to a server specified by the server_ip.
    % there will be an input stream to receive data and an output stream to send data.
    %
    % input stream:
    % - input_port_client has to be the output port of the server, e.g., 2000
    % - input_socket_client is the socket for incoming data
    % - input_stream_client is the stream, check here whether data is
    % available
    % - d_input_stream_client is where you read Data from
    %
    % output stream:
    % - output_port_client has to be the input pot of the server, e.g., 2001
    % - client_socket is the socket for the output stream, it is
    % output_socket_client when it is accepted by the other side
    % - output_stream_client is the stream, you don't really need it
    % - d_output_stream_client is where you write Data to

    % import java stuff
    import java.net.ServerSocket
    import java.net.Socket
    import java.io.*

    % preallocate some variables
    retry = 0;
    connected_input = 0;
    connected_output = 0;
    input_socket_client  = [];
    client_socket  = [];
    output_socket_client  = [];
    buffer_size = 1200;
    
    while connected_input == 0 || connected_output == 0
        % check whether max_retries have been reached
        retry = retry + 1;
        if ((number_of_retries > 0) && (retry > number_of_retries))
            fprintf(1, 'Too many retries\n');
            break;
        end
        % 
        try
            %% setup input stream from server to client (we are the client)
            if connected_input == 0
                fprintf(1, 'Retry %d connecting to server %s:%d\n', ...
                    retry, server_ip, input_port_client);
                % throws if unable to connect
                input_socket_client = Socket(server_ip, input_port_client);
                % get a buffered data input stream from the socket
                input_stream_client   = input_socket_client.getInputStream;
                d_input_stream_client = DataInputStream(input_stream_client);
                % alter the receive buffer size here
                disp('Buffer sizes for input stream (old and new) coming up:');
                input_receive_buffer_size = input_socket_client.getReceiveBufferSize;
                disp(input_receive_buffer_size);
                input_socket_client.setReceiveBufferSize(buffer_size);
                input_receive_buffer_size_new = input_socket_client.getReceiveBufferSize;
                disp(input_receive_buffer_size_new);
                % set tcp to no delay
                input_socket_client.setTcpNoDelay(1);
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
                client_socket.setSoTimeout(1000);
                % get output buffer size and set it to a new value
                disp('Buffer sizes for output stream (old and new) coming up:');
                output_receive_buffer_size = client_socket.getReceiveBufferSize;
                disp(output_receive_buffer_size);
                client_socket.setReceiveBufferSize(buffer_size);
                output_receive_buffer_size_new = client_socket.getReceiveBufferSize;
                disp(output_receive_buffer_size_new);
                
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
            if ~isempty(input_socket_client)
                input_socket_client.close;
            end
            if ~isempty(client_socket)
                client_socket.close;
            end
            if ~isempty(output_socket_client)
                output_socket_client.close;
            end
            % pause before retrying
            pause(1);
            %rethrow(ME);
        end
    end
end