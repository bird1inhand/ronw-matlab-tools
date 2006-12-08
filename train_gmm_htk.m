function gmm = train_gmm_htk(trdata, nmix, niter, verb, CVPRIOR, mu0);
% gmmparams = train_gmm_htk(trdata, nmix, niter, verb, cvprior, mu0);
%
% Train a GMM with diagonal covariance using HTK.
%
% Inputs:
% trdata - training data (cell array of training sequences, each
%                         column of the sequences arrays contains ana
%                         observation)
% nmix   - number of mixture components.  Defaults to 3.
% niter  - number of EM iterations to perform.  Defaults to 10.
% verb   - set to 1 to output loglik at each iteration
%
% Outputs:
% gmmparams - structure containing hmm parameters learned from training
%             data (gmm.priors, gmm.means(:,1:nmix), gmm.covars(:,1:nmix))
%
% 2006-12-06 ronw@ee.columbia.edu


% based on trainhmmhtk.m
if nargin < 2
  nmix = 3;
end
if nargin < 3
  niter = 10;
end

if nargin < 4
  verb = 0;
end

% prior on observation covariances to avoid overfitting:
if nargin < 5
  CVPRIOR = 1;
end

if ~iscell(trdata)
  trdata = {trdata};
end

% HRest complains bitterly if there are fewer than 3 training
% sequence, but since we are training a gmm we can cheat and steal
% the last two columns of trdata{1} and treat them as separate
% training sequences.
nseq = length(trdata);
if nseq < 3
  tmp = trdata{1};
  trdata{1} = tmp(:,1:end-2);
  trdata{nseq+1} = tmp(:,end-1);
  trdata{nseq+2} = tmp(:,end);
  nseq = nseq + 2;
end
[ndim, nobs(1)] = size(trdata{1});

% initial HMM parameters - only 1 state since we're learning a GMM.
hmm.emission_type = 'GMM';
hmm.nstates = 1;
hmm.transmat = log(0.9);
hmm.start_prob = 0;
hmm.end_prob = log(0.1);

% uniform prior
gmm.priors = log(ones(1, nmix)/nmix);
gmm.nmix = nmix;

if nargin < 6 | numel(mu0) == 1 & mu0 == 1
  gmm.means = kmeans(cat(2, trdata{:}), nmix, niter/2);
else
  if size(mu0, 2) == nmix
    gmm.means = mu0;
  end
end

gmm.covars = ones(ndim, nmix);
hmm.gmms = {gmm};

% write temp files for each sequence

% Temporary file to use
rnd = num2str(round(10000*rand(1)));
for n = 1:length(trdata)
  datafilename{n} = ['/tmp/matlabtmp_htkdat_' rnd '_' num2str(n) ...
        '.dat']; 

  % custom data format:
  htkcode = 9;  % USER
  %htkcode = 6;  % MFCC
  htkwrite(trdata{n}', datafilename{n}, htkcode);
end

% initial HTK HMM: HInit/HCompV? 
hmmfilename = ['/tmp/matlabtmp_htkhmm_' rnd];
write_htk_hmm(hmmfilename, hmm); 
use_hinit = 0;
if use_hinit
  args = ['-i ' num2str(niter) ' -v ' num2str(CVPRIOR)];
  args = [args ' -T 1'];
  if verb > 1
    args = [args ' -A -V -D'];
  end
  disp('running HInit...');
  datestr(now)
  system(['HInit ' args ' ' hmmfilename ' ' sprintf('%s ', datafilename{:})]);
  datestr(now)
  disp('done.');
end 

% run HRest to train:
args = ['-t -M /tmp -i ' num2str(niter) ' -v ' num2str(CVPRIOR)];
if verb
  args = [args ' -T 3'];
  if verb > 1
    args = [args ' -A -V -D'];
  end
end
system([get_htk_path() 'HRest ' args ' ' hmmfilename ' ' sprintf('%s ', datafilename{:})]);

if verb
  disp(['******** DONE ********'])
end

% read in hmm:
hmm = read_htk_hmm(hmmfilename);
gmm = hmm.gmms{1};

% clean up:
system(['rm ' hmmfilename]);
system(['rm ' sprintf('%s ', datafilename{:})]);

% done.
