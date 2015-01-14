function [bNode,bEdge,node,bflag] = meshBoundary(P, KV,n_el,options)
%---------------------------------meshBoundary---------------------------------%
% This funciton meshes the boundaries of the domain. It takes as an input a
% NURBS curve ( in the form of its control points and knot vector) and a
% user defined number of elements to mesh the edge with. It outputs a series
% of control nets and nodal points corresponding to one "layer" of
% triangular elements along the boundary. It also outputs a list of nodes
% that fall on the outer boundary jsut created (bNode) and a connectivity
% array of these nodes(bEdge). These are for passing to a third party mesh
% generator to mesh the interior volume that's away from the edges.


% Inputs:
% P = control points of the nurbs curve
% KV = knot vector of the nurbs curve.

% Output
% B: a 1 x 2*nel cell of control nets

% node:
%------------------------------------------------------------------------------%

% Calculate the degree of the inputed Nurbs curve:
% number of knots:
m = length(KV);
% number of control points:
n = size(P,1);
% From the relation: m = n+p+1:
p = m-n-1;

% Normalize the knot vector:
KV = KV/KV(end);

% Save a copy of the original
KV0 = KV;
% Initialize variables:
bNode = zeros(n_el,2);
bEdge = zeros(n_el,2);

a = zeros(length(P),1);
Q = zeros(size(P));

% Based on the number of elements wanted along the boundary, calculate the
% desired final knot vector:

if  p == 1
    n_el = size(P,1)-1;
    bNode = P(1:end-1,1:2);
    for ee = 1:n_el
        bEdge(ee,:) = [ee,ee+1];
    end
    
    bEdge(end,2) = 1;
    
elseif p == 2
    % Calculate the number of control points along the curve:
    nP = n_el*2+1;
    nKV = nP + p +1;
    
    % Assume equal spacing of elements along the curve. Functionality for
    % weighted element sizing can be added later. Calculate the location of
    % the knots:
    kvLoc = 0:1/n_el:1;
    
    % Initialize the desired final knot vector:
    KVF = zeros(1,nKV);
    % The knot at 0 will have multiplicity 3, so don't change the first
    % three entries of KVF. The knot at the end will also have multiplicity
    % three, change the last three entries to 1.
    KVF(nKV-p:nKV) = [1 1 1];
    
    % The middle knots will all have multiplicity of 2, so loop through and
    % assign the rest of the knots
    ctr = 4;
    for iKV = 2:length(kvLoc)-1
        KVF(ctr)   = kvLoc(iKV);
        KVF(ctr+1) = kvLoc(iKV);
        ctr = ctr+2;
    end
    
elseif p == 3
    % Calculate the number of control points along the curve:
    nP = n_el*3+1;
    nKV = nP + p +1;
    % Assume equal spacing of elements along the curve. Functionality for
    % weighted element sizing can be added later. Calculate the location of
    % the knots:
    kvLoc = 0:1/n_el:1;
    
    % Initialize the desired final knot vector:
    KVF = zeros(1,nKV);
    
    % The first knot will have multiplicity of 4, so don't change the first
    % four entries. The last knot will also have multiplicity of 4, so
    % assign the last four entries to 1
    KVF(nKV-p:nKV) = [1 1 1 1];
    
    % The middle knots will all have multiplicity of 3, so loop through and
    % assign the rest of the knots
    ctr = 5;
    for iKV = 2:length(kvLoc)-1
        KVF(ctr)   = kvLoc(iKV);
        KVF(ctr+1) = kvLoc(iKV);
        KVF(ctr+2) = kvLoc(iKV);
        ctr = ctr+3;
    end
    
else
    display('This function only supports NURBS curves of degree 2 or 3')
    return
end

% Convert the NURBS curve to a 4D b-spline by multipling all the control
% points by their respective weights.
P(:,1) = P(:,1).*P(:,3);
P(:,2) = P(:,2).*P(:,3);

% Knot Interstion:
% We know what we want our final knot vector to look like, so we'll do knot
% insertion until our KV matches our KVF.
for i = 1:length(KVF)
    % Check to see if the current knot in KV matches the current knot in
    % KVF. If it does, great, move on to the next knot, if not, calculate
    % new control points and insert KVF(i) into KV(i).
    if KVF(i) == KV(i)
        continue
    else
        
        % Correct for the algorithm indexing by zero
        ki = i-1;
        
        % Calculate the new control points
        % Loop through indexes from k-p+1 to k and calculate the new control
        % points
        for j = ki-p+1:ki
            a(j) = (KVF(i)-KV(j))/(KV(j+p)-KV(j));
            Q(j,:) = (1-a(j))*P(j-1,:) + a(j)*P(j,:);
        end
        
        % Move control points below ki-1 down by 1 space to
        % make room for the p new points;
        P(ki+1:length(P)+1,:) = P(ki:length(P),:);
        % Insert the new control points
        P(ki-p+1:ki,:) = Q(ki-p+1:ki,:);
        
        % move the knots to the right of the knot to be inserted over one
        % index
        KV(i+1:end+1) = KV(i:end);
        
        % Insert the knot to the knot vector.
        KV(i) = KVF(i);
    end
end

% If the inputted curve was quadratic, do degree elevation to get a cubic curve.
if p==2
    clear Q
    ctr1 = 1;
    ctr2 = 1;
    for e = 1:n_el
        [Q(ctr1:ctr1+3,:),pe] = elevateDegree(P(ctr2:ctr2+2,:),p);
        ctr1 = ctr1+3;
        ctr2 = ctr2+2;
    end
    
    
    P = Q;
    p  = pe;
    
    kvLoc = unique(KV);
    nKV = length(P)+p+1;
    % Go in and change the knot vector.
    % Initialize the desired final knot vector:
    KVe = zeros(1,nKV);
    
    % The first knot will have multiplicity of 4, so don't change the first
    % four entries. The last knot will also have multiplicity of 4, so
    % assign the last four entries to 1
    KVe(nKV-p:nKV) = [1 1 1 1];
    
    % The middle knots will all have multiplicity of 3, so loop through and
    % assign the rest of the knots
    ctr = 5;
    for iKV = 2:length(kvLoc)-1
        KVe(ctr)   = kvLoc(iKV);
        KVe(ctr+1) = kvLoc(iKV);
        KVe(ctr+2) = kvLoc(iKV);
        ctr = ctr+3;
    end
end

% Now that the knot insertion is done, renormalize all the control points
% by their respective weights to get a NURBS description again.
P(:,1) = P(:,1)./P(:,3);
P(:,2) = P(:,2)./P(:,3);


if options.lift
    % Loop through all the boundary control points just created and make a
    % triangular mesh layer.
    ctr = 1;
    for n = 1:n_el
        bPts = P(ctr:ctr+3,:);
        [node{n}] = gen_netb(bPts);
        ctr = ctr+3;
    end
    
    % fill in between the triangles that have an edge on the boundary
    % with more triangles.
    for n = 1:n_el
        % Add the third node of the current triangle to the boundary node array
        bNode(n,:) = node{n}(3,1:2);
    end
    
    for i = 1:n_el-1
        vert = [node{i}(1,:);node{i}(3,:);node{i+1}(3,:)];
        [node{n_el+i}] = gen_net(vert);
    end
    
    % Connect the last element to the first element.
    vert = [node{n_el}(1,:);node{n_el}(3,:);node{1}(3,:)];
    [node{n_el*2}] = gen_net(vert);
    
    % Finally, generate the bEdge connectivity array.
    for i = 1:n_el-1
        bEdge(i,:) = [i, i+1];
    end
    bEdge(n_el,:) = [n_el, 1];
    
else
    
    bb = 1:3:length(P);
    bNode = P(bb(1:end-1),1:2);
    for ee = 1:n_el
        bEdge(ee,:) = [ee,ee+1];
        node{ee} = P(bb(ee):bb(ee+1),:);
    end
    
    bEdge(end,2) = 1;
    
    % Findout which knot span of the original knot vector each element lies
    % on
    KV0 = unique(KV0);
    KVF = unique(KVe);
    bb = zeros(n_el,1);
    for kk = 2:length(KV0)
        bb(kk) = sum(KVF>KV0(kk-1) & KVF<KV0(kk))+1;
        bsum = cumsum(bb);    
        bflag(bsum(kk-1)+1:bsum(kk),1) = ones(bb(kk),1)*(kk-1);
    end
    
    

    
end

return