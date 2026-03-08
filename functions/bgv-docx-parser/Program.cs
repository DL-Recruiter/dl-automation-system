using bgv_docx_parser.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var host = new HostBuilder()
    .ConfigureFunctionsWebApplication()
    .ConfigureServices(services =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
        services.AddSingleton<IDocxCheckboxExtractor, OpenXmlDocxCheckboxExtractor>();
        services.AddSingleton<IAuthorizationMatchEvaluator, AuthorizationMatchEvaluator>();
        services.AddSingleton<IDrawingDetectionService, OpenXmlDrawingDetectionService>();
    })
    .Build();

host.Run();
