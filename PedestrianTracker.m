classdef PedestrianTracker < handle
 
    properties (Access = private)
        
        timestep;
        
        pedestrians;
        pedestrian_motion_model;
        
        figure_handle;
    end
    
    methods
        
        %% Constructor
        
        function obj = PedestrianTracker()
            
            obj.timestep = 1;
            
            obj.pedestrians = {};
            obj.pedestrian_motion_model = PedestrianMotionModel();
            
            obj.figure_handle = figure();
        end
        
        %% Misc

        function increment_time(obj)
            obj.timestep = obj.timestep + 1;
        end
        
        function update_state(obj)
            
            for i = 1:length(obj.pedestrians)
               obj.pedestrians{i}.update_state();
            end
        end
        
        function remove_inactive_pedestrians(obj)
           
            active_indices = [];
            
            for i = 1:length(obj.pedestrians)
                if(~obj.pedestrians{i}.is_inactive())
                    active_indices(length(active_indices) + 1) = i;
                end
            end
            
            if (length(active_indices) < length(obj.pedestrians))
                obj.pedestrians = {obj.pedestrians{active_indices}};
            end
        end
        
        function update_position_histories(obj)
            
            for i = 1:length(obj.pedestrians)
               obj.pedestrians{i}.update_position_history();
            end
        end
        
        %% Measurement handling
        
        function inititalize_measurement_series(obj)
            
            for i = 1:length(obj.pedestrians)
               obj.pedestrians{i}.initialize_measurement_series(obj.timestep);
            end
        end
        
        function distribute_position_measurement(obj, position_measurement)
            
            global c;
            
            % Search for connection between pedestrian and measurement
            % I.e. if the measurement falls into the box that defines the
            % the pedestrian
            
            pedestrian_connected_to_measurement = -1;
            best_pedestrian_connection_metric = Inf;
            
            for i = 1:length(obj.pedestrians)
               
                pedestrian_position = obj.pedestrians{i}.get_position();
                position_offset = position_measurement - pedestrian_position;
                
                if (abs(position_offset(1)) <= (c.PEDESTRIAN_WIDTH / 2)) && (abs(position_offset(2)) <= (c.PEDESTRIAN_HEIGHT / 2))
                    
                    pedestrian_connection_metric = norm(position_offset) - 0.5 * max(20, obj.pedestrians{i}.get_age());
                    
                    if (pedestrian_connection_metric < best_pedestrian_connection_metric)
                        
                        pedestrian_connected_to_measurement = i;
                        best_pedestrian_connection_metric = pedestrian_connection_metric;
                    end
                end
            end
            
            % Assign the measurement to the pedestrian which is predicted
            % to be closest to the measurement
            
            if (pedestrian_connected_to_measurement > 0)
                
                obj.pedestrians{pedestrian_connected_to_measurement}.add_position_measurement(position_measurement);
            
            % If no connection was found initialize a new pedestrian
            
            else
                index = length(obj.pedestrians) + 1;

                obj.pedestrians{index} = Pedestrian(position_measurement, obj.timestep);
            end
        end
        
        %% Plots
        
        function has_closed_figure = plot(obj, current_time, current_frame, difference_image, position_measurements, position_measurement_labels)
       
            global c;
            
            % If the user has closed the figure window, exit
            
            if (~ishandle(obj.figure_handle))
                has_closed_figure = true;
                return;
            end
            
            has_closed_figure = false;
            
            % Else show desired plots set in the c file
            
            if (c.DISPLAY_DIFFERENCE_IMAGE)
                imshow(difference_image);
            else
                imshow(current_frame);
            end

            hold on;
            
            if (c.DISPLAY_TIMESTAMP)
                obj.plot_timestamp(current_time);
            end

            if (c.DISPLAY_MEASUREMENTS)
                
                if (nargin >= 5)
                    obj.plot_position_measurements_with_labels(position_measurements, position_measurement_labels);
                else
                    obj.plot_position_measurements(position_measurements);
                end
            end

            if (c.DISPLAY_PEDESTRIAN_RECTANGLES)
                obj.plot_bounding_boxes();
                obj.plot_position_histories();
            end
            
            hold off;
        end
        
        % Time
        
        function plot_timestamp(obj, current_time)
            text(20, 20, num2str(current_time), 'Color', 'r', 'FontSize', 18);
        end
        
        % Position measurements
        
        function plot_position_measurements_with_labels(obj, position_measurements, position_measurement_labels)
        
            global c;
            
            for i = 1:size(position_measurements, 2)
                
                marker_style = 'ro';
                
                if (position_measurement_labels(i) == c.MEASUREMENT_LABEL_PEDESTRIAN)
                    marker_style = 'rd';
                elseif (position_measurement_labels(i) == c.MEASUREMENT_LABEL_CLUTTER)
                    marker_style = 'rs';
                end
                
                plot(position_measurements(1, i), position_measurements(2, i), marker_style);
            end
        end
        
        function plot_position_measurements(obj, position_measurements)
        
            for i = 1:size(position_measurements, 2)
                plot(position_measurements(1, i), position_measurements(2, i), 'rx');
            end
        end
        
        % Pedestrians
        
        function plot_bounding_boxes(obj)
            
            global c;
            
            for i = 1:length(obj.pedestrians)
                
                if (~(c.DISPLAY_ONLY_ACTIVE_PEDESTRIANS && strcmp(obj.pedestrians{i}.get_state(), c.INITIALIZATION)))
                    obj.pedestrians{i}.plot_bounding_box();
                end
            end
        end
        
        function plot_position_histories(obj)
            
            global c;
            
            for i = 1:length(obj.pedestrians)
                if (~(c.DISPLAY_ONLY_ACTIVE_PEDESTRIANS && strcmp(obj.pedestrians{i}.get_state(), c.INITIALIZATION)))
                    obj.pedestrians{i}.plot_position_history();
                end
            end
        end
        
        %% Kalman filter
        
        function kalman_prediction(obj)
            
            for i = 1:length(obj.pedestrians)
               obj.pedestrians{i}.kalman_prediction(obj.pedestrian_motion_model);
            end
        end
        
        function kalman_update(obj)
            
            for i = 1:length(obj.pedestrians)
               obj.pedestrians{i}.kalman_update(obj.pedestrian_motion_model);
            end
        end
    end
    
end

