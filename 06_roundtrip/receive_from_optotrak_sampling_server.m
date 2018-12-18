function [data_available, sample_data, bytes_available, dur1, dur2, dur3] = receive_from_optotrak_sampling_server(in_stream, d_in_stream)
    
    % this function checks whether data is available in the input stream,
    % then reads it and converts it to an array of numbers (if it has the
    % right format)
    
    dur1 = 0;
    dur2 = 0;
    dur3 = 0;
    
    bytes_available = in_stream.available;
    if bytes_available > 0 % check whether there is data waiting in the stream
        tic;
%         disp('Bytes available:');
%         disp(bytes_available);
        message_from_otherside = char( d_in_stream.readUTF );
        dur1 = toc;
%         disp('message_from_otherside received');
%         disp(message_from_otherside);

        % is message a str converted from an array? like this: '[1 2 3]'
        if strcmp(message_from_otherside(1), '[') && strcmp(message_from_otherside(end), ']')
            %% if so, convert the message
            % split to cell array. remove the brackets on position 1 & end
            a = splitstr(message_from_otherside(2:end-1), ' ');
%             disp(a);
            dur2 = toc - dur1;
            % convert to numbers
            sample_data = str2doubleq(a);
            %disp(sample_data);
            data_available = 1;
            dur3 = toc - dur2 - dur1;
        else  % it is not a data sample
            data_available = 0;
            sample_data = message_from_otherside;
        end
    else % return 
        data_available = 0;
        sample_data = [];
    end
end