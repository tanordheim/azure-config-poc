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
                return CloudConfigurationManager.GetSetting("test_setting");
            }
            return ConfigurationManager.AppSettings["test_setting"];
        }
	}
}