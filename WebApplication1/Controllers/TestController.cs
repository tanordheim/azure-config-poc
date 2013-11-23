using System.Configuration;
using System.Web.Mvc;
using Microsoft.WindowsAzure;
using Microsoft.WindowsAzure.ServiceRuntime;

namespace WebApplication1.Controllers
{
    public class TestController : Controller
    {
        //
        // GET: /Test/
        public ActionResult Index()
        {
            var value = GetTestValue();
            return Content(string.Format("Retrieved value: {0}", value));
        }

        private string GetTestValue()
        {
            if (RoleEnvironment.IsAvailable && !RoleEnvironment.IsEmulated)
            {
                var env = CloudConfigurationManager.GetSetting("ENVIRONMENT");
                var envSetting = ConfigurationManager.AppSettings[string.Format("{0}_test_setting", env)];
                if (!string.IsNullOrWhiteSpace(envSetting))
                {
                    return envSetting;
                }
            }
            return ConfigurationManager.AppSettings["test_setting"];
        }
	}
}