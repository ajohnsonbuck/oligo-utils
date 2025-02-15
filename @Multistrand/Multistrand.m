classdef Multistrand
    properties
        Sequences = {Strand(); Strand()}; % Cell array of two Strand objects
        Duplexes = {}; % Cell array of Duplex objects describing one or more duplexes formed by the pair. By default, the first is the longest.
    end
    methods
        function objArray = Multistrand(varargin) % Constructor
            args = varargin;
            if length(args) == 1
                if isa(args{1},'Strand')
                    objArray(1,numel(args{1})) = Multistrand();
                    for n = 1:numel(args{1})
                        objArray(n).Sequences{1} = args{1}(n);
                    end
                elseif isa(args{1},'string') || isa(args{1},'char') || isa(args{1},'cell')
                    objArray(1).Sequences{1} = Strand(args{1});
                else
                    error('Input must be one or two Strand objects, chars, strings, or sequences');
                end
                for n = 1:numel(objArray)
                    objArray(n).Sequences{2} = objArray(n).Sequences{1}.reverseComplement; % Create reverse complement
                    if ~isempty(objArray(n).Sequences{1}.Name)
                        objArray(n).Sequences{2}.Name = [objArray(n).Sequences{1}.Name,'_reverseComplement'];
                    end
                end
            elseif length(args) == 2
                for n = 1:2
                    if isa(args{n},'Strand')
                        for p = 1:numel(args{1})
                            objArray(p).Sequences{n} = args{n}(p);
                        end
                    elseif isa(args{n},'string') || isa(args{n},'char') || isa(args{n},'cell')
                        objArray(1).Sequences{n} = Strand(args{n});
                    else
                        error('Input must be one or two Strand objects, chars, strings, or sequences');
                    end
                end
            end
            for n = 1:numel(objArray)
                if sum(contains(objArray(n).Sequences{2}.Sequence,'r'))<sum(contains(objArray(n).Sequences{1}.Sequence,'r'))
                    objArray(n).Sequences = flipud(objArray(n).Sequences); % If either sequence has RNA, ensure Sequence 2 has more RNA residues
                end
                if sum(contains(objArray(n).Sequences{2}.Sequence,'+'))>sum(contains(objArray(n).Sequences{1}.Sequence,'+'))
                    objArray(n).Sequences = flipud(objArray(n).Sequences); % If either sequence has LNA, ensure Sequence 1 has more LNA residues
                end
                if sum(contains(objArray(n).Sequences{2}.Sequence,'b'))>sum(contains(objArray(n).Sequences{1}.Sequence,'b'))
                    objArray(n).Sequences = flipud(objArray(n).Sequences); % If either sequence has BNA, ensure Sequence 1 has more BNA residues
                end
                if ~isempty(objArray(n).Sequences{1}.String)
                    objArray(n) = findLongestDuplex(objArray(n));
                end
            end
        end
        function a = findLongestDuplex(a) % Find duplex with largest number of base pairs
            objArray = a;
            for m = 1:numel(objArray)
                objArray(m) = applyMask(objArray(m));
                % Create schema with padding (empty cells) for all possible registers
                schema = cell(2,objArray(m).Sequences{2}.len + (objArray(m).Sequences{1}.len-1)*2);
                schema(2,objArray(m).Sequences{1}.len:objArray(m).Sequences{1}.len+objArray(m).Sequences{2}.len-1) = objArray(m).Sequences{2}.toDNA.reverseComplement.bareSequence; % Reverse complement of bare DNA version of first sequence
                seq1 = objArray(m).Sequences{1}.toDNA.bareSequence; % first sequence to be slid across second sequence and compared
                nbest = objArray(m).Sequences{1}.len;
                ncomp_best = 0; % highest number of complementary base pairs
                comp_best = zeros(1,size(schema,2)); % matrix of complementary base pairs
                % Determine register of schema with most base pairs
                for n=1:size(schema,2)-objArray(m).Sequences{1}.len+1
                    schema(1,:) = cell(1,size(schema,2)); % empty first row
                    schema(1,n:n+objArray(m).Sequences{1}.len-1) = seq1;
                    comp = cellfun(@strcmp,schema(1,:),schema(2,:));
                    ncomp = sum(comp);
                    if ncomp > ncomp_best
                        ncomp_best = ncomp;
                        comp_best = comp;
                        nbest = n;
                    end
                end
                % Reconstruct schema with largest number of base pairs
                schema = cell(2,objArray(m).Sequences{2}.len + (objArray(m).Sequences{1}.len-1)*2);
                schema(2,objArray(m).Sequences{1}.len:objArray(m).Sequences{1}.len+objArray(m).Sequences{2}.len-1) = objArray(m).Sequences{2}.reverse().Sequence;
                schema(1,nbest:nbest+objArray(m).Sequences{1}.len-1) = objArray(m).Sequences{1}.Sequence;
                % Trim schema of any padding
                ind = any(~cellfun(@isempty,schema),1);
                startpos = find(ind,1,'first');
                endpos = find(ind,1,'last');
                schema = schema(:, startpos:endpos); % trim
                schema(cellfun(@isempty,schema))={''}; % Replace empty cell elements with empty char
                % Create duplex object and place in original Multistrand array
                a(m).Duplexes{1} = Duplex(schema,'Sequences',objArray(m).Sequences);
            end
        end
        function duplex = longestDuplex(objArray)
            for n = 1:numel(objArray) 
                duplex(n) = objArray(n).Duplexes{1};
            end
        end
        function list(obj) % List nucleic acid sequences in pair as strings
            for n = 1:2
                fprintf(1,'Sequence %d: %s\n',n,obj.Sequences{n}.String);
            end
        end
        function Tm = estimateTm(objArray,varargin)
            args = varargin;
            Tm = zeros(numel(objArray),1);
            for n = 1:numel(objArray)
                duplex = objArray(n).longestDuplex();
                if ~isempty(varargin)
                    Tm(n) = duplex.estimateTm(args{:});
                else
                    Tm(n) = duplex.estimateTm();
                end
            end
        end
        function objArray = applyMask(objArray)
            for m = 1:numel(objArray)
                for n = 1:numel(objArray(m).Sequences)
                    mask = objArray(m).Sequences{n}.Mask;
                    if isempty(mask)
                        mask = repmat('n',1,objArray(m).Sequences{n}.len);
                    end
                    str1 = objArray(m).Sequences{n}.String;
                    for p = 1:objArray(m).Sequences{n}.len
                        if strcmp(mask(p),'-')
                            objArray(m).Sequences{n}.Sequence{p}='-';
                        end
                    end
                    objArray(m).Sequences{n} = objArray(m).Sequences{n}.fromSequence;
                    objArray(m).Sequences{n}.UnmaskedString = str1;
                end
            end
        end
        function print(objArray)
            for m = 1:numel(objArray)
                for n = 1:numel(objArray(m).Sequences)
                    fprintf(1,'\n Sequence %d: %s',n,objArray(m).Sequences{n}.Name)
                    fprintf(1,[char("\n5'-"),objArray(m).Sequences{n}.String,char("-3'\n")]);
                end
            end
            fprintf(1,'\n');
        end
    end
end