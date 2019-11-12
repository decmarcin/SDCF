%% Code to two Examples used in SDCF article 
%  Marcin Dec 2019

% ========================================================================
% Cube of correlated normal variables (the small epsilons in the article)

%clearvars;
file_prefix='ex2'; % figures saved (*.eps) have this unique txt inside the filename

% Params 
nr_sims=400000;
nr_vars=3;
nr_vars_notCorrel = 1;
nr_timesteps=100;
SigmaCorrel = [1 0.75 0.10; 0.75 1 -0.25; 0.10 -0.25 1];

tic
disp('Simulating random numbers from proper distributions')
% Preps
LowerTSigmaCorrel = chol (SigmaCorrel);
CubeRaw = randn (nr_sims, nr_timesteps, nr_vars); % the array of uncorrelated Zets
CubeCorr = zeros (nr_sims, nr_timesteps, nr_vars); % array preparation (memory)

% Correlate the raw random normal numbers in slices
for s=1:nr_sims
    CubeCorr (s, :, :) = squeeze(CubeRaw (s, :, :)) * LowerTSigmaCorrel;
end


% Simulate other - not correlated but still stochastic variables
CubeNotCorrelRaw = zeros (nr_sims, nr_timesteps, nr_vars_notCorrel);
X4_lambda=0.07;

for s=1:nr_sims
    CubeNotCorrelRaw (s, :, 1) =  (poissrnd(X4_lambda,nr_timesteps,1)) * randi([-1,1]) ;
end
toc


% ========================================================================
% X-variables Cube (for CFs directly generated by SDEs and some "exo" variables used for other scaled CFs)

CubeX = zeros (nr_sims, nr_timesteps, nr_vars + nr_vars_notCorrel); % array preparation (memory)

% Params of Xes - SDE governing: GBM
dt=1; % setting time step to one year (small delta in the artilce)

% Sales of product 1 (pieces),  SDE governing: GBM, Direct CF modelling
X1_start=120;
X1_miu = 0.01;
X1_sigma=0.5;

% Sales of product 2 (pieces),   SDE governing: CIR, Direct CF modelling
X2_start=80;
X2_theta = 75;
X2_kappa=0.1;
X2_sigma=0.5;

% Business climate,  SDE governing: OU , "Exo" variable used in CubeCF
X3_start=5;
X3_theta = 0;
X3_kappa=0.1;
X3_sigma=0.5;


% Regulatory costs (unexpected),  SDE governing: pure Poisson , "Exo" variable used in CubeCF
X4_scale =10000;


disp('Starting the loop CubeX')
tic
for x=1:(nr_vars + nr_vars_notCorrel)
    for s=1:nr_sims
        for t=1:nr_timesteps
            if t==1
                switch x
                    case 1
                        CubeX(s, t, x) = X1_start;
                    case 2
                        CubeX(s, t, x) = X2_start;
                    case 3
                        CubeX(s, t, x) = X3_start;
                    case 4
                        CubeX(s, t, x) = 0;
                    otherwise
                        disp('variable number out of scope')
                end
            else
                switch x
                    case 1
                        CubeX(s, t, x) = CubeX(s, t-1, x) * (1 +  X1_miu * dt) + X1_sigma * sqrt(dt) * CubeCorr(s, t, x);
                    case 2
                        CubeX(s, t, x) = CubeX(s, t-1, x) + X2_kappa * (X2_theta - CubeX(s, t-1, x)) * dt + X2_sigma * sqrt(dt* CubeX(s, t-1, x)) * CubeCorr(s, t, x); 
                    case 3
                        CubeX(s, t, x) = CubeX(s, t-1, x) + X3_kappa * (X3_theta - CubeX(s, t-1, x)) * dt + X3_sigma * sqrt(dt) * CubeCorr(s, t, x);
                    case 4
                        CubeX(s, t, x) = CubeNotCorrelRaw (s, t, 1) * X4_scale ;
                    otherwise
                        disp('variable number out of scope')
                end
            end
        end
    end
end
toc


% ========================================================================
% Cube of scaled and auxilary variables 

nr_cf_vars=8; % total number of vars (directly simulated and scaled)
CubeS = zeros (nr_sims, nr_timesteps, nr_cf_vars); % array preparation (memory)

% copying directly simulated CF variables from CubeX
CubeS(:,:,1)=CubeX(:,:,1);
CubeS(:,:,2)=CubeX(:,:,2);

% Parameters of different scaled or auxilary variables
% cf3: prices of product 1 (business cycle dependent)
S3_px_scale=1;  S3_px_base=40;

% cf4: prices of product 2 (business cycle dependent)
S4_px_scale=2;  S4_px_base=80;

% cf5: semi fixed costs - depending on the total sales - Heaviside function
S5_high_util=17000; S5_low_util=12000; S5_costs_when_high=13000; S5_costs_when_mid=9500; S5_costs_when_low=9000;

% cf6: financial costs (business cycle dependent)
S6_scale=50; S6_lvl=400; S6_crisis_threshold= -4; S6_crisis_scale=-80;

% cf7: tax rate (expressing long term view of taxes going down)
S7_tax_rate=0.20; S7_tax_decrease_rate_ann=0.003; % compounded
CubeS(:, 1, 7) = S7_tax_rate;


disp('Starting the loop CubeS')
tic
for x=3:7
    for s=1:nr_sims
        for t=1:nr_timesteps
            switch x
                case 3
                    CubeS(s, t, x) = max(1, CubeX(s, t, 3) * S3_px_scale + S3_px_base);
                case 4
                    CubeS(s, t, x) = max(1, CubeX(s, t, 3) * S4_px_scale + S4_px_base);
                case 5
                    TotalSales = CubeS(s, t, 3) * CubeX(s, t, 1) + CubeS(s, t, 4) * CubeX(s, t, 2);
                    CubeS(s, t, 8) = TotalSales;
                    if (TotalSales > S5_high_util)
                        CubeS(s, t, x) = S5_costs_when_high;
                    elseif (TotalSales < S5_low_util)
                        CubeS(s, t, x) = S5_costs_when_low;
                    else
                        CubeS(s, t, x) = S5_costs_when_mid;
                    end
                case 6
                    if CubeX(s, t, 3)>S6_crisis_threshold
                        CubeS(s, t, x) = max(S6_lvl, CubeX(s, t, 3) * S6_scale);
                    else
                        CubeS(s, t, x) = max(S6_lvl, CubeX(s, t, 3) * S6_crisis_scale);
                    end
                case 7
                    if t>1
                        CubeS(s, t, x) = CubeS(s, t-1, x) * (1- S7_tax_decrease_rate_ann);
                    end
                otherwise
                    disp('variable number out of scope')
            end
        end
    end
end
toc

% ========================================================================
% Cube of CFs and their sum
nr_cf=5; % total number of vars (directly simulated and scaled)
CubeCF = zeros (nr_sims, nr_timesteps, nr_cf+1); % array preparation (memory)
disc_rate = 0.02;

% collecting already simulated CFs:
CubeCF(:,:,1)=CubeS(:,:,8); % Total sales
CubeCF(:,:,2)=CubeS(:,:,5); % Semi fixed costs
CubeCF(:,:,3)=CubeS(:,:,6); % Financial costs
CubeCF(:,:,4)=CubeX(:,:,4); % Regulatory costs (from Poisson process)
CubeCF(:,:,5)=(CubeCF(:,:,1)-CubeCF(:,:,2)-CubeCF(:,:,3)-CubeCF(:,:,4)).*(1-CubeS(:, :, 7));
for t=1:nr_timesteps
    for s=1:nr_sims
        CubeCF(s,t,6) = CubeCF(s,t,5) / (1 + disc_rate) ^ t;
    end
end


% sample histogram of V_SDCF
V_SDCF=zeros(1,nr_sims);

for s=1:nr_sims
    V_SDCF(s) = sum(CubeCF(s,:,6)); 
end

V_SDCFex2=V_SDCF;
% % ========================================================================
% % sample histogram of V_SDCF
% fig=figure('Renderer', 'painters', 'Position',[10 10 800 350]);
% histogram(V_SDCF, 'Normalization','probability', 'DisplayStyle', 'stairs', 'linewidth', 1); 
% grid on
% saveas(fig,char(strcat({'SDCF_'},file_prefix,{'_Dist_VSDCF.eps'})), 'epsc');






% ========================================================================
% V_SDCF transformation by comparing it to v0
% plus all individual risk measures proposed

% Individual's parameters
v0 = 105000; % reference point valuation (i.e. current market price of the investment
tsl = -0.05; % stop-loss return defined by an individual
trf =  0.07; % risk-free target return (or alternative)
tbe =  0.03; % break-even return (including round trip costs of investment and harvesting)

% V_SDCF transformation
V_SDCF_trans=(V_SDCF./v0)-1;
q01=quantile(squeeze(transpose(V_SDCF_trans)), 0.01);
q99=quantile(squeeze(transpose(V_SDCF_trans)), 0.99);
r= linspace(q01-0.05,q99+0.05,100);
r_band=(q99-q01)/100;

pd_kernel_V_SDCF_trans = fitdist(squeeze(transpose(V_SDCF_trans)),'Kernel', 'Bandwidth', r_band);
pdf_kernel_V_SDCF_trans = pdf(pd_kernel_V_SDCF_trans, r);

% Individual risk asseeement measures
prob_exeed_stop_loss = cdf(pd_kernel_V_SDCF_trans, tsl);
prob_exeed_risk_free = 1- cdf(pd_kernel_V_SDCF_trans, trf);
prob_exeed_break_even = 1- cdf(pd_kernel_V_SDCF_trans, tbe);
impl_optimism_ratio= (prob_exeed_break_even) / (1- prob_exeed_stop_loss);
mkt_eff_dist=abs(0.5 - cdf(pd_kernel_V_SDCF_trans, trf));
reserv_01=quantile(squeeze(transpose(V_SDCF_trans)), 0.01);
reserv_05=quantile(squeeze(transpose(V_SDCF_trans)), 0.05);
reserv_10=quantile(squeeze(transpose(V_SDCF_trans)), 0.10);
tmean = quantile(squeeze(transpose(V_SDCF_trans)), 0.5); % average return from SDCF valuation
alphaKT=0.88; betaTK=0.88; lambdaKT=2.25;
Uex2=[V_SDCF_trans(V_SDCF_trans>=0).*alphaKT, -lambdaKT* ((-V_SDCF_trans(V_SDCF_trans<0)).*betaTK)];
UCurlyEx2=sum(Uex2)/nr_sims;

% All in one graph
fig=figure('Renderer', 'painters', 'Position',[100 100 1000 700]);
histogram(V_SDCF_trans,  'Normalization','probability', 'linewidth', 1, 'EdgeAlpha', 0.01,'FaceAlpha', 0.3, 'FaceColor',[0.5 0.5 0.5], 'BinWidth', r_band)
hold on
line([tsl, tsl], ylim, 'LineWidth', 2, 'Color', 'r');
line([trf, trf], ylim, 'LineWidth', 2, 'Color', 'g');
line([tbe, tbe], ylim, 'LineWidth', 1, 'Color', 'b');
line([tmean, tmean], ylim, 'LineWidth', 1, 'Color', 'k', 'linestyle', '--');
legend('$\tilde{V}_{SDCF}$','$t_{sl}$','$t_{rf}$','$t_{be}$','$t_{mean}$', 'Interpreter','latex', 'Fontsize', 14)
grid on
xlabel('t - transformed returns')
ylabel('normalised probability')

dim = [0.7 0.3 0.3 0.3];
str = {char(strcat({'$P(t<t_{sl})=$ '},num2str(round(prob_exeed_stop_loss,4)))), ...
    char(strcat({'$P(t>t_{be})=$ '},num2str(round(prob_exeed_break_even,4)))), ...
    char(strcat({'$P(t>t_{rf})=$ '},num2str(round(prob_exeed_risk_free,4)))),...
    char(strcat({'$\Omega=$ '},num2str(round(impl_optimism_ratio,4)))),...
    char(strcat({'$\epsilon=$ '},num2str(round(mkt_eff_dist,4)))),...
    char(strcat({'$t_{min, 99\%}=$ '},num2str(round(reserv_01,4)))),...
    char(strcat({'$t_{min, 95\%}=$ '},num2str(round(reserv_05,4)))),...
    char(strcat({'$t_{min, 90\%}=$ '},num2str(round(reserv_10,4)))),...
    char(strcat({'$\mathcal{U}=$ '},num2str(round(UCurlyEx2,4))))};
annotation('textbox',dim,'String',str,'FitBoxToText','on', 'Interpreter','latex', 'Fontsize', 12);

saveas(fig,char(strcat({'SDCF_'},file_prefix,{'_RISK_VSDCF.eps'})), 'epsc');









%
%
%
% ==========================================================================
%
%


% ========================================================================
% Cube of correlated normal variables (the small epsilons in the article)


file_prefix='ex1'; % figures saved (*.eps) have this unique txt inside the filename

% Params 
nr_sims=400000;
nr_vars=3;
nr_timesteps=100;
SigmaCorrel = [1 0.75 0.10; 0.75 1 -0.25; 0.10 -0.25 1];

% Preps
LowerTSigmaCorrel = chol (SigmaCorrel);
CubeRaw = randn (nr_sims, nr_timesteps, nr_vars); % the array of uncorrelated Zets
CubeCorr = zeros (nr_sims, nr_timesteps, nr_vars); % array preparation (memory)

% Correlate the raw random nomrmal numbers in slices
for s=1:nr_sims
    CubeCorr (s, :, :) = squeeze(CubeRaw (s, :, :)) * LowerTSigmaCorrel;
end

% ========================================================================
% X-variables Cube (for CFs directly generated by SDEs and some "exo" variables used for other scaled CFs)
CubeX = zeros (nr_sims, nr_timesteps, nr_vars); % array preparation (memory)

% Params of Xes - SDE governing: GBM
dt=1; % setting time step to one year (small delta in the artilce)

% Sales of product 1 (pieces),  SDE governing: GBM, Direct CF modelling
X1_start=120;
X1_miu = 0.01;
X1_sigma=0.5;

% Sales of product 2 (pieces),   SDE governing: CIR, Direct CF modelling
X2_start=80;
X2_theta = 75;
X2_kappa=0.1;
X2_sigma=0.5;

% Business climate,  SDE governing: OU , "Exo" variable used in CubeCF
X3_start=5;
X3_theta = 0;
X3_kappa=0.1;
X3_sigma=0.5;

disp('Starting the loop CubeX')
tic
for x=1:3
    for s=1:nr_sims
        for t=1:nr_timesteps
            if t==1
                switch x
                    case 1
                        CubeX(s, t, x) = X1_start;
                    case 2
                        CubeX(s, t, x) = X2_start;
                    case 3
                        CubeX(s, t, x) = X3_start;
                    otherwise
                        disp('variable number out of scope')
                end
            else
                switch x
                    case 1
                        CubeX(s, t, x) = CubeX(s, t-1, x) * (1 +  X1_miu * dt) + X1_sigma * sqrt(dt) * CubeCorr(s, t, x);
                    case 2
                        CubeX(s, t, x) = CubeX(s, t-1, x) + X2_kappa * (X2_theta - CubeX(s, t-1, x)) * dt + X2_sigma * sqrt(dt* CubeX(s, t-1, x)) * CubeCorr(s, t, x); 
                    case 3
                        CubeX(s, t, x) = CubeX(s, t-1, x) + X3_kappa * (X3_theta - CubeX(s, t-1, x)) * dt + X3_sigma * sqrt(dt) * CubeCorr(s, t, x);
                    otherwise
                        disp('variable number out of scope')
                end
            end
        end
    end
end
toc


% ========================================================================
% Cube of scaled and auxilary variables 

nr_cf_vars=8; % total number of vars (directly simulated and scaled)
CubeS = zeros (nr_sims, nr_timesteps, nr_cf_vars); % array preparation (memory)

% copying directly simulated CF variables from CubeX
CubeS(:,:,1)=CubeX(:,:,1);
CubeS(:,:,2)=CubeX(:,:,2);

% Parameters of different scaled or auxilary variables
% cf3: prices of product 1 (business cycle dependent)
S3_px_scale=1;  S3_px_base=40;

% cf4: prices of product 2 (business cycle dependent)
S4_px_scale=2;  S4_px_base=80;

% cf5: semi fixed costs - depending on the total sales - Heaviside function
S5_high_util=17000; S5_low_util=12000; S5_costs_when_high=13000; S5_costs_when_mid=9500; S5_costs_when_low=9000;

% cf6: financial costs (business cycle dependent)
S6_scale=50; S6_lvl=400; S6_crisis_threshold= -4; S6_crisis_scale=-80;

% cf7: tax rate (expressing long term view of taxes going down)
S7_tax_rate=0.20; S7_tax_decrease_rate_ann=0.003; % compounded
CubeS(:, 1, 7) = S7_tax_rate;


disp('Starting the loop CubeS')
tic
for x=3:7
    for s=1:nr_sims
        for t=1:nr_timesteps
            switch x
                case 3
                    CubeS(s, t, x) = max(1, CubeX(s, t, 3) * S3_px_scale + S3_px_base);
                case 4
                    CubeS(s, t, x) = max(1, CubeX(s, t, 3) * S4_px_scale + S4_px_base);
                case 5
                    TotalSales = CubeS(s, t, 3) * CubeX(s, t, 1) + CubeS(s, t, 4) * CubeX(s, t, 2);
                    CubeS(s, t, 8) = TotalSales;
                    if (TotalSales > S5_high_util)
                        CubeS(s, t, x) = S5_costs_when_high;
                    elseif (TotalSales < S5_low_util)
                        CubeS(s, t, x) = S5_costs_when_low;
                    else
                        CubeS(s, t, x) = S5_costs_when_mid;
                    end
                case 6
                    if CubeX(s, t, 3)>S6_crisis_threshold
                        CubeS(s, t, x) = max(S6_lvl, CubeX(s, t, 3) * S6_scale);
                    else
                        CubeS(s, t, x) = max(S6_lvl, CubeX(s, t, 3) * S6_crisis_scale);
                    end
                case 7
                    if t>1
                        CubeS(s, t, x) = CubeS(s, t-1, x) * (1- S7_tax_decrease_rate_ann);
                    end
                otherwise
                    disp('variable number out of scope')
            end
        end
    end
end
toc

% ========================================================================
% Cube of CFs and their sum
nr_cf=4; % total number of vars (directly simulated and scaled)
CubeCF = zeros (nr_sims, nr_timesteps, nr_cf+1); % array preparation (memory)
disc_rate = 0.02;

% collecting already simulated CFs:
CubeCF(:,:,1)=CubeS(:,:,8); % Total sales
CubeCF(:,:,2)=CubeS(:,:,5); % Semi fixed costs
CubeCF(:,:,3)=CubeS(:,:,6); % Financial costs
CubeCF(:,:,4)=(CubeCF(:,:,1)-CubeCF(:,:,2)-CubeCF(:,:,3)).*(1-CubeS(:, :, 7));
for t=1:nr_timesteps
    for s=1:nr_sims
        CubeCF(s,t,5) = CubeCF(s,t,4) / (1 + disc_rate) ^ t;
    end
end

V_SDCF=zeros(1,nr_sims);

for s=1:nr_sims
    V_SDCF(s) = sum(CubeCF(s,:,5)); 
end

V_SDCFex1=V_SDCF;
% % ========================================================================
% % sample histogram of V_SDCF
% fig=figure('Renderer', 'painters', 'Position',[10 10 850 350]);
% histogram(V_SDCF, 'Normalization','probability', 'DisplayStyle', 'stairs', 'linewidth', 1); 
% grid on
% saveas(fig,char(strcat({'SDCF_'},file_prefix,{'_Dist_VSDCF.eps'})), 'epsc');



% ========================================================================
% V_SDCF transformation by comparing it to v0
% plus all individual risk measures proposed

% Individual's parameters
v0 = 105000; % reference point valuation (i.e. current market price of the investment
tsl = -0.05; % stop-loss return defined by an individual
trf =  0.07; % risk-free target return (or alternative)
tbe =  0.03; % break-even return (including round trip costs of investment and harvesting)

% V_SDCF transformation
V_SDCF_trans=(V_SDCF./v0)-1;
q01=quantile(squeeze(transpose(V_SDCF_trans)), 0.01);
q99=quantile(squeeze(transpose(V_SDCF_trans)), 0.99);
r= linspace(q01-0.05,q99+0.05,100);
r_band=(q99-q01)/100;

pd_kernel_V_SDCF_trans = fitdist(squeeze(transpose(V_SDCF_trans)),'Kernel', 'Bandwidth', r_band);
pdf_kernel_V_SDCF_trans = pdf(pd_kernel_V_SDCF_trans, r);

% Individual risk asseeement measures
prob_exeed_stop_loss = cdf(pd_kernel_V_SDCF_trans, tsl);
prob_exeed_risk_free = 1- cdf(pd_kernel_V_SDCF_trans, trf);
prob_exeed_break_even = 1- cdf(pd_kernel_V_SDCF_trans, tbe);
impl_optimism_ratio= (prob_exeed_break_even) / (1- prob_exeed_stop_loss);
mkt_eff_dist=abs(0.5 - cdf(pd_kernel_V_SDCF_trans, trf));
reserv_01=quantile(squeeze(transpose(V_SDCF_trans)), 0.01);
reserv_05=quantile(squeeze(transpose(V_SDCF_trans)), 0.05);
reserv_10=quantile(squeeze(transpose(V_SDCF_trans)), 0.10);
tmean = quantile(squeeze(transpose(V_SDCF_trans)), 0.5); % average return from SDCF valuation
Uex1=[V_SDCF_trans(V_SDCF_trans>=0).*alphaKT, -lambdaKT* ((-V_SDCF_trans(V_SDCF_trans<0)).*betaTK)];
UCurlyEx1=sum(Uex1)/nr_sims;



% All in one graph
fig=figure('Renderer', 'painters', 'Position',[100 100 1000 700]);
histogram(V_SDCF_trans,  'Normalization','probability', 'linewidth', 1, 'EdgeAlpha', 0.01,'FaceAlpha', 0.3, 'FaceColor',[0.5 0.5 0.5], 'BinWidth', r_band)
hold on
line([tsl, tsl], ylim, 'LineWidth', 2, 'Color', 'r');
line([trf, trf], ylim, 'LineWidth', 2, 'Color', 'g');
line([tbe, tbe], ylim, 'LineWidth', 1, 'Color', 'b');
line([tmean, tmean], ylim, 'LineWidth', 1, 'Color', 'k', 'linestyle', '--');
legend('$\tilde{V}_{SDCF}$','$t_{sl}$','$t_{rf}$','$t_{be}$','$t_{mean}$', 'Interpreter','latex', 'Fontsize', 14)
grid on
xlabel('t - transformed returns')
ylabel('normalised probability')

dim = [0.7 0.3 0.3 0.3];
str = {char(strcat({'$P(t<t_{sl})=$ '},num2str(round(prob_exeed_stop_loss,4)))), ...
    char(strcat({'$P(t>t_{be})=$ '},num2str(round(prob_exeed_break_even,4)))), ...
    char(strcat({'$P(t>t_{rf})=$ '},num2str(round(prob_exeed_risk_free,4)))),...
    char(strcat({'$\Omega=$ '},num2str(round(impl_optimism_ratio,4)))),...
    char(strcat({'$\epsilon=$ '},num2str(round(mkt_eff_dist,4)))),...
    char(strcat({'$t_{min, 99\%}=$ '},num2str(round(reserv_01,4)))),...
    char(strcat({'$t_{min, 95\%}=$ '},num2str(round(reserv_05,4)))),...
    char(strcat({'$t_{min, 90\%}=$ '},num2str(round(reserv_10,4)))),...
       char(strcat({'$\mathcal{U}=$ '},num2str(round(UCurlyEx1,4))))};
annotation('textbox',dim,'String',str,'FitBoxToText','on', 'Interpreter','latex', 'Fontsize', 12);

saveas(fig,char(strcat({'SDCF_'},file_prefix,{'_RISK_VSDCF.eps'})), 'epsc');








%% Joint figure for two distributions


file_prefix='twoexamples';
% ========================================================================
% sample histogram of V_SDCF
fig=figure('Renderer', 'painters', 'Position',[10 10 800 350]);
histogram(V_SDCFex2, 'Normalization','probability', 'DisplayStyle', 'stairs', 'linewidth', 1, 'BinWidth', 1000); 
hold on
histogram(V_SDCFex1, 'Normalization','probability', 'DisplayStyle', 'stairs', 'linewidth', 1, 'BinWidth', 1000); 
grid on
legend('Example 1','Example 2')
saveas(fig,char(strcat({'SDCF_'},file_prefix,{'_Dist_VSDCF.eps'})), 'epsc');




