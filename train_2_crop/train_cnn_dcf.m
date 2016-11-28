function [net, info] = train_cnn_dcf(varargin)
%CNN_DCF
run('vl_setupnn.m') ;
fftw('planner','patient');
opts.network = [] ;
opts.networkType = 'dagnn' ;
opts.expDir = fullfile('../data', 'vot-vgg-dcf') ;
opts.dataDir = fullfile('../data', 'vot16') ;
opts.imdbPath = fullfile(opts.expDir, 'imdb.mat');
opts.lite = ismac();

if ispc()
    trainOpts.gpus = [1];
else
    trainOpts.gpus = [];
end
trainOpts.learningRate = 1e-5;
trainOpts.weightDecay = 0.0005;
trainOpts.numEpochs = 50;
trainOpts.batchSize = 1;
opts.train = trainOpts;

if ~isfield(opts.train, 'gpus'), opts.train.gpus = []; end;

% --------------------------------------------------------------------
%                                                         Prepare data
% --------------------------------------------------------------------

if isempty(opts.network)
  net = cnn_dcf_init() ;
else
  net = opts.network ;
  opts.network = [] ;
end

if exist(opts.imdbPath, 'file')
  imdb = load(opts.imdbPath) ;
else
  imdb = getVOTImdb('lite',opts.lite) ;
  if ~exist(opts.expDir,'dir'),mkdir(opts.expDir);end
  save(opts.imdbPath, '-v7.3', '-struct', 'imdb') ;
end

% --------------------------------------------------------------------
%                                                                Train
% --------------------------------------------------------------------

switch opts.networkType
  case 'simplenn', trainfn = @cnn_train ;
  case 'dagnn', trainfn = @cnn_train_dag ;
end

[net, info] = trainfn(net, imdb, getBatch(opts), ...
  'expDir', opts.expDir, ...
  opts.train, ...
  'val', find(imdb.images.set == 2)) ;

netStruct = net.saveobj() ;
save('./vgg16_dcf.mat', '-v7.3', '-struct', 'netStruct') ;
clear netStruct ;

end

% --------------------------------------------------------------------
function fn = getBatch(opts)
% --------------------------------------------------------------------
bopts = struct('numGpus', numel(opts.train.gpus),'sz', [125,125]) ;
fn = @(x,y) getDagNNBatch(bopts,x,y) ;
end

% --------------------------------------------------------------------
function inputs = getDagNNBatch(opts, imdb, batch)
% --------------------------------------------------------------------
if opts.numGpus > 0
    target = gpuArray(single(imdb.images.target{batch}));
    search = gpuArray(single(imdb.images.search{batch}));
    bbox_target = gpuArray(imdb.images.target_bboxs(batch,:));
    bbox_search = gpuArray(imdb.images.search_bboxs(batch,:));
else
    target = single(imdb.images.target{batch});
    search = single(imdb.images.search{batch});
    bbox_target = imdb.images.target_bboxs(batch,:);
    bbox_search = imdb.images.search_bboxs(batch,:);
end

inputs = {'bbox_target',bbox_target,'bbox_search',bbox_search,...
    'image_target', target, 'image_search', search} ;
end