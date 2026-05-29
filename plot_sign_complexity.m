function [oneSign, mdl, xfit, yfit] = plot_sign_complexity(sign_list, selectedSign)
%% Plot sign complexity over time for one MDC sign

    selectedSign = string(selectedSign);

    requiredVars = ["mdc", "date", "complexity", "shapes"];
    missingVars = requiredVars(~ismember(requiredVars, string(sign_list.Properties.VariableNames)));

    if ~isempty(missingVars)
        error('sign_list is missing required variables: %s', strjoin(missingVars, ', '));
    end

    mdcVals = string(sign_list.mdc);
    oneSign = sign_list(mdcVals == selectedSign, :);

    if isempty(oneSign)
        error('No rows found for selectedSign = %s', selectedSign);
    end

    x = oneSign.date;
    y = oneSign.complexity;

    figure(gcf); clf
    ax = axes;
    hold(ax, 'on');

    xlim(ax, [-2700 500]);
    ylim(ax, [min(oneSign.complexity)-1000 max(oneSign.complexity)]+500);

    shapescatter(oneSign.shapes, x, y, 20, [], ax);

    mdl = fitlm(x, y);
    xfit = linspace(min(x), max(x), 100)';
    yfit = predict(mdl, xfit);

    plot(ax, xfit, yfit, 'LineWidth', 1);

    xlabel(ax, 'Date', 'FontName', 'Minion Pro Hiero');
    ylabel(ax, 'Complexity', 'FontName', 'Minion Pro Hiero');

    grid(ax, 'on');
    box(ax, 'on');

    slope = mdl.Coefficients.Estimate(2);

    title(ax, sprintf('%s | slope = %.4f', selectedSign, slope), ...
        'FontName', 'Minion Pro Hiero');

    hold(ax, 'off');
end