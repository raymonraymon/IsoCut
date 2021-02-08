function [hm,ha,hb,hl]=VisualizeScalarFieldOnTriMesh(TR,F,ha,avp)
% Visualize scalar field on a triangular mesh.
%
% INPUT:
%   - TR    : surface  mesh represented as an object of 'TriRep' class,
%             'triangulation' class, or a cell such that TR={Tri,V}, where
%             Tri is an M-by-3 array of faces and V is an N-by-3 array of 
%             vertex coordinates.
%   - F     : N-by-1 vector specifying values of the scalar field at 
%             the vertices of TR.
%   - ha    : optional input argument specifying handle of the axes
%             where mesh will be visualized.
%   - avp   : optional input argument specifying structure generated by the
%             'GetAxesViewProps' function.
%
% OUTPUT:
%   - hm    : mesh handle
%   - ha    : axes handle
%   - hb    : colorbar handle
%   - hl    : lighthing object handles 
%
% AUTHOR: Anton Semechko (a.semechko@gmail.com)
%


if nargin<3, ha=[]; end
if nargin<4, avp=[]; end

[Tri,V,fmt]=GetMeshData(TR);

if size(V,2)==2,  V(:,3)=0; end
if fmt>1, TR=triangulation(Tri,V); end


flag=false;
if isempty(ha) || ~strcmpi(get(ha,'type'),'axes')
    figure('color','w')
    flag=true;
else
    axes(ha)
end

hm=trimesh(TR);
set(hm,'EdgeColor','none','FaceColor','interp','FaceVertexCData',F(:),...
       'CDataMapping','scaled','SpecularStrength',0.6)
   
set(hm,'SpecularExponent',35,'SpecularStrength',0.15)
   
ha=gca;
colormap('jet')

hb=colorbar;
axis equal off vis3d
hold on
set(hb,'FontSize',30)

if ~isempty(avp), MatchAxesView(avp,ha); end

h1=camlight('headlight');
set(h1,'style','infinite','position',10*get(h1,'position'))
h2=light('position',-get(h1,'position'));
set(h2,'style','infinite')
lighting phong
hl=[h1 h2];

if flag && numel(unique(F))>1 
    set(ha,'CLimMode','manual','CLim',[min(F) max(F)]);    
end

if nargout<1
    clear hm ha hb hl
end
    