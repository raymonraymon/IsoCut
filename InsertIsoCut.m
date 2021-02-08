function TRc=InsertIsoCut(TR,C,FV)
% Locally modify connectivity of a triangular surface mesh so that it 
% contains edges coincident with an iso-contour computed with the 
% 'IsoContour' function. 
%
%!!!!!!!!!!!!!!!!!!!!!!!!!!!! IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
% At this time, the mesh can be "cut" using only closed iso-contours. The 
% special case where the cut intersects with boundary edge(s) is not yet 
% supported. You do NOT have to worry about this exception if 
%   (a) the input surface mesh is closed, OR 
%   (b) the input surface mesh is open AND the cut does not intersect any of
%       its boundary edges 
%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
%
% INPUT:
%   - TR    : input surface mesh represented as an object of 'TriRep' 
%             class, 'triangulation' class, or a cell such that TR={Tri,X},
%             where Tri is an M-by-3 array of faces and X is an N-by-3 
%             array of vertex coordinates.  
%   - C     : N-by-3 ORDERED list of coordinates of the cut you wish to
%             make in the input mesh. 
%   - FV    : N-by-4 list of barycentric coordinates corresponding to C.
%             Note, both C and FV are the outputs of the 'OrderIsoContourVerts'
%             function; which pre-procecess the iso-countr(s) genenerated 
%             by the 'IsoContour' function to ensure proper vertex order.  
%
% OUTPUT:
%   - TRc   : input surface mesh whose connectivity has been locally 
%             modified to insert the cut specified by C and FV.     
%
% AUTHOR: Anton Semechko (a.semechko@gmail.com)
%


if nargin<3 || isempty(TR) || isempty(C) || isempty(FV)
    error('Insufficent number of input arguments')
end

if ~isnumeric(C) || ~ismatrix(C) || size(C,2)~=3 || size(C,1)<3
    error('Invalid entry for 2nd inpupt argument (C)')
end

if ~isnumeric(C) || ~ismatrix(FV) || size(FV,2)~=4 || size(FV,1)~=size(C,1)
    error('Invalid entry for 3rd inpupt argument (FV)')
end

[Tri,X,fmt]=GetMeshData(TR);
clear TR
Nx=size(X,1);


% Insert check for closed contour condition (for now), because the 
% implementation assumes every edge cut by the contour shares two faces. 
% If a cut passes though a boundary edge, implementation will fail.
if norm(C(1,:)-C(end,:))>eps
    error('Input contour must be closed')
end

% Assign indices to contour vertices. This automatically accounts for 
% unprobable, but possible, cases where contour passes though existing 
% vertices.
Nc=size(C,1)-1;
k=0;

v_id=zeros(Nc+1,1);
Xc=zeros(0,3);  % unique list of contour vertices that has NULL intersection with X 

tol=1E-15;
for i=1:Nc
    t=FV(i,3);
    if t<=tol
        v_id(i)=FV(i,1);
    elseif t>=(1-tol)
        v_id(i)=FV(i,2);
    else
        k=k+1;
        v_id(i)=Nx + k;
        Xc(k,:)=C(i,:);
    end
end
v_id(Nc+1)=v_id(1); % indices assigned to points in C

% Update vertex list
X=cat(1,X,Xc);


% Modify connectivity
% -------------------------------------------------------------------------
Tri_new=zeros(0,3);
Quad_new=zeros(0,4);
[cnt_tri,cnt_quad]=deal(0);
for n=1:Nc

    % Points containing the line segment 
    fv1=FV(n,:);    
    fv2=FV(n+1,:);   
    
    % Case1: Cut passes through an existing edge so connectivity doesn't 
    % have to be modified
    if (fv1(3)<=tol || fv1(3)>=(1-tol)) && (fv2(3)<=tol || fv2(3)>=(1-tol))
        continue        
    end

    % Case 2: Cut passes through an existing vertex --> Triangle gets split
    % into two smaller triangles
    chk=true;
    if fv1(3)<=tol
        v=fv1(1);        % 1st point of the cut passes thought this vertex
        fv=fv2;          % 2nd point of the cut passeses though here 
        v_new=v_id(n+1); % index of the 2nd point
    elseif fv1(3)>=(1-tol)
        v=fv1(2);
        fv=fv2;
        v_new=v_id(n+1);
    elseif fv2(3)<=tol
        v=fv2(1);
        fv=fv1;
        v_new=v_id(n);
    elseif fv2(3)>=(1-tol)
        v=fv2(2);
        fv=fv1;
        v_new=v_id(n);
    else
        chk=false; % must be Case 3 
    end
    
    if chk
        cnt_tri=cnt_tri+1;
        % Modify connectivy of the cut triangle. Modification is reflected
        % in both Tri and Tri_new. Tri_new contains the 2nd triangle
        % generated by the cut.
        [Tri,Tri_new(cnt_tri,:)]=split_face_1(v,fv,Tri,v_new);
        continue
    end
    
    % Case 3: Cut passes through two distinct edges. Thus triangle gets 
    % split into one smaller triangle and one quadrilateral. This is by far 
    % the most common case. Smaller triangle gets saved into Tri and 
    % quadrilateral into Quad_new
    cnt_quad=cnt_quad+1;
    [Tri,Quad_new(cnt_quad,:)]=split_face_2(fv1,fv2,Tri,[v_id(n) v_id(n+1)]);
    
end

% -------------------------------------------------------------------------
if ~isempty(Quad_new)
    TriQuad=Quad2Tri(Quad_new,X);
    Tri_new=cat(1,Tri_new,TriQuad);
end

switch fmt
    case 1
        TRc=triangulation(cat(1,Tri,Tri_new),X);
    case 2
        TRc=TriRep(cat(1,Tri,Tri_new),X); %#ok<*DTRIREP>
    case 3
        TRc={cat(1,Tri,Tri_new) X};
    case 4
        TRc=struct('faces',cat(1,Tri,Tri_new),'vertices',X);
end



function [Tri,quad_new]=split_face_2(fv1,fv2,Tri,v_new)
% Split triangle into one smaller triangle and one quadrilateral using a 
% line segment that cuts though two of its edges.
%
%   - fv1, fv2  : barycetric coordinates of the line segment end-points 
%   - Tri       : mesh connectivity
%   - v_new     : 1-by-2 vector of vertex indices assigned to fv1 and fv2 


fv1=fv1(1:2);
fv2=fv2(1:2);
fv=[fv1 fv2];

% Identify triangle
idx=ismember(Tri,fv);
idx=sum(idx,2)==3;
idx=find(idx);

% Put vertex common to fv1 and fv2 at the top
tri=Tri(idx,:);
if sum(fv==tri(2))==2
    tri=circshift(tri,[0 -1]);
elseif sum(fv==tri(3))==2
    tri=circshift(tri,[0 -2]);
end

if sum(ismember(tri([1 3]),fv1))==2
    v_new=v_new([2 1]);
end

% Modify connectivity
Tri(idx,:)=[tri(1) v_new];
quad_new=[v_new(1) tri(2:3) v_new(2)];


function [Tri,tri_new]=split_face_1(v,fv,Tri,v_new)
% Split triangle into two smaller triangles using a line segment that 
% starts at vertex v and terminates at the opposing edge.
%
%   - v     : existing vertex coinsident with the cut
%   - fv    : opposing edge
%   - Tri   : mesh connectivity
%   - v_new : index of the new vertex on the opposing edge
  

% Identify triangle containing the cut
idx=ismember(Tri,[v fv(1:2)]);
idx=sum(idx,2)==3;
idx=find(idx);

% Put v at the top
tri=Tri(idx,:);
id=find(tri==v);
tri=circshift(tri,[0 1-id]);

% Modify connectivity
Tri(idx,:)=[tri([1 2]) v_new];
tri_new=[tri([3 1]) v_new];

