function [TRc,Fc,C,H]=IsoCut(TR,F,iv,vis)
% Cut triangular surface mesh along a level set of a scalar field defined
% at the mesh vertices.
%
% INPUT:
%   - TR    : input surface mesh represented as an object of 'TriRep' 
%             class, 'triangulation' class, or a cell such that TR={Tri,X},
%             where Tri is an M-by-3 array of faces and X is an N-by-3 
%             array of vertex coordinates. 
%   - F     : N-by-1 array specifying values of the scalar field at the 
%             mesh vertices. 
%   - iv    : real number specifying level set value along which the cut
%             will be generated.
%   - vis   : axes handle (or logical value) indicating where (or whether)
%             computed level sets should be plotted. 
%
% OUTPUT: 
%   - TRc   : input mesh with modified connectivty so that it contains
%             new edges coincident witht the cut F=iv.
%   - Fc    : scalar field defined at the vertices of TRc.
%   - C     : K-by-1 cell containing level set vertices
%   - H     : iso-contour handles. 
%
% AUTHOR: Anton Semechko (a.semechko@gmail.com)
%


% Basic error checking
if nargin<3 || isempty(TR) || isempty(F) || isempty(iv)
   error('Insufficient number of input arguments') 
end

[Tri,X,fmt]=GetMeshData(TR);
if fmt>1, TR=triangulation(Tri,X); end

F=F(:);
N=size(X,1);
if ~isnumeric(F) || ~isvector(F) || numel(F)~=N || any(isnan(F) | isinf(F))
    edit('Invalid entry for 2nd input argument (F)')
end

if ~isscalar(iv) || ~isfinite(iv) 
    error('Invalid entry for 3rd input argument (iv)')
elseif iv<min(F) || iv>max(F)
    error('Specified iso-value (%10e) is not in the domain of F',iv)
end

if nargin<4 || isempty(vis)
    vis=false;
elseif numel(vis)~=1 || ~((ishandle(vis) && strcmpi(get(vis,'type'),'axes')) || islogical(vis))
    error('Invalid entry for 4th input argument (vis)')
end


%% Get the level set / cut
[C,~,VT,H]=IsoContour(TR,F,iv*[1 1],vis);


%% Order vertices 
tol=1E-15;
[C,VT]=OrderIsoContourVerts(C,VT,tol);


%% Insert cut into the mesh. Nore a single level set can be composed of 
% multiple contours. These have to inserted into the mesh separately and
% are subject to the constains that they are closed and non-self
% intersecting.
TRc=TR;
clear TR

Fc=F(:);
K=numel(C);
for k=1:K
    
    if isempty(C{k}), continue; end
    
    TRc=InsertIsoCut(TRc,C{k},VT{k});       
    
    if nargout>1
        dN=size(TRc.Points,1)-N;      
        Fc=cat(1,Fc,repmat(iv,[dN 1]));
        N=N+dN;
    end    
    
end


%% Output mesh in the same format as the input
if fmt>1
    [Tri,X]=GetMeshData(TRc);
    switch fmt
        case 2
            TRc=TriRep(Tri,X); %#ok<*DTRIREP>
        case 3
            TRc={Tri X};
        case 4
            TRc=struct('faces',Tri,'vertices',X);
    end    
end
