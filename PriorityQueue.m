%% -------- PriorityQueue Class Example (min-heap) --------
classdef PriorityQueue < handle
    properties
        heap = [];  % array of label-struct
    end
    
    methods
        function insert(obj, label)
            obj.heap = [obj.heap, label];
            obj.bubbleUp(length(obj.heap));
        end
        
        function label = pop(obj)
            % Return min label
            if obj.isEmpty()
                label = [];
                return;
            end
            label = obj.heap(1);
            obj.heap(1) = obj.heap(end);
            obj.heap(end) = [];
            obj.bubbleDown(1);
        end
        
        function tf = isEmpty(obj)
            tf = isempty(obj.heap);
        end
    end
    
    methods (Access = private)
        function bubbleUp(obj, idx)
            parent = floor(idx/2);
            if parent < 1, return; end
            if obj.heap(idx).cost < obj.heap(parent).cost
                obj.swap(idx, parent);
                obj.bubbleUp(parent);
            end
        end
        
        function bubbleDown(obj, idx)
            left = idx*2;
            right = idx*2 + 1;
            smallest = idx;
            
            if left <= length(obj.heap) && obj.heap(left).cost < obj.heap(smallest).cost
                smallest = left;
            end
            if right <= length(obj.heap) && obj.heap(right).cost < obj.heap(smallest).cost
                smallest = right;
            end
            if smallest ~= idx
                obj.swap(idx, smallest);
                obj.bubbleDown(smallest);
            end
        end
        
        function swap(obj, i, j)
            tmp = obj.heap(i);
            obj.heap(i) = obj.heap(j);
            obj.heap(j) = tmp;
        end
    end
end