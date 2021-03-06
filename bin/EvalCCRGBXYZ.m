function [ cielabE ] = EvalCCRGBXYZ( varargin )
%% EVALCCFUNC Evaluate a colour correction function given RGB and XYZ
%   [ cielabE ] = EvalCCRGBXYZ(rgb, xyz, genCC, applyCC);
%
%   Required parameters:
%       rgb : A n-times-3 matrix containing RGB response of the cameras, 
%           n being the
%       xyz : A n-times-3 matrix containing the  corresponding tristimulus
%           values. 
%       genCC : The function for generation colour correction matrix
%       applyCC : The function for applying colour correction matrix
%
%   Optional parameters:
%       foldInd : The fold index for cross validation

%% Set up the input parser
p = inputParser;

% Required parameters
% The matrix which contains the camera responses
addRequired(p, 'rgb', @(x) ismatrix(x) && size(x, 2));
% The matrix which contains the corresponding tristimulus values
addRequired(p, 'xyz', @(x) ismatrix(x) && size(x, 2) == 3);
% genCC, the function for generation the colour correction matrix
addRequired(p, 'genCC', @(x) isa(x, 'function_handle'));
% applyCC, the function for applying the colour correction matrix
addRequired(p, 'applyCC', @(x) isa(x, 'function_handle'));

% Optional parameters
% foldInd, the fold index for cross validation
addOptional(p, 'foldInd', [], @(x) isvector(x) || isempty(x));

% Parse the varargin
parse(p, varargin{:});

%% Initial variable assignment
% Assign the things came out from the input parser (saves me from typing)
RGB = p.Results.rgb;
XYZ = p.Results.xyz;
genCC = p.Results.genCC;
applyCC = p.Results.applyCC;
foldInd = p.Results.foldInd;

% Assign white point
wpXYZ = GetWpFromColourChecker(XYZ);
wpRGB = GetWpFromColourChecker(RGB);

% Normalise exposure by dividing the green channel
XYZ = XYZ./wpXYZ(2);
RGB = RGB./wpRGB(2);
wpXYZ = wpXYZ./wpXYZ(2);
wpRGB = wpRGB./wpRGB(2);

% Calculate the number of folds
foldCount = max(foldInd(:));
% Handle empty foldInd
if isempty(foldInd)
    foldCount = 1;
end

if size(RGB, 1) ~= size(XYZ,1)
    error('EvalCCRGBXYZ:input_size_mismatch', ... 
        'RGB matrix and XYZ matrix differ in size');
end

% CIELAB error matrix
cielabE = [];

% The true CIELAB 
LAB = xyz2lab(XYZ, 'WhitePoint', wpXYZ);



%% The main loop
% This implements cross validation
for i = 1:foldCount
    % Note that we use 't' for training, 'v' for validation.
    
    if isempty(foldInd)
        % Handle empty foldInd
        vInd = true(size(RGB,1),1);
        tInd = vInd;
    else
        % Setting the indices
        % Verfication set is fold i.
        vInd = (foldInd == i);
        % Training set are the folds that are not fold i.
        tInd = ~vInd;
    end
%     disp(['tInd:' num2str(sum(tInd)) ' vInd: ' num2str(sum(vInd))]);
    
    % Extracting the training data for this fold
    tRGB = RGB(tInd, :);
    tXYZ = XYZ(tInd, :);
    
    % Tag on the white point at the end of the training set
    tRGB(end, :) = wpRGB;
    tXYZ(end, :) = wpXYZ;
    
    % Training the colour correction matrix
    ccm = genCC(tRGB, tXYZ);
    
    % Generate the validation set
    vRGB = RGB(vInd, :);
    
    vTrueLab = LAB(vInd, :);
    
    % Apply colour correction
    vCamXYZ = applyCC(vRGB, ccm);
    vCamXYZ = vCamXYZ(1:end,:);

    vCamLab = xyz2lab(vCamXYZ, 'WhitePoint', wpXYZ);

    vCielabE = sqrt(sum((vCamLab - vTrueLab).^2, 2));
    cielabE = [cielabE; vCielabE]; %#ok<AGROW>
    
end

end

