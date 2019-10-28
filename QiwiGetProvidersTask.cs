using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using OneBill;
using OneBill.Common;
using OneBill.Data;
using OneBillElecsnet.Logic.Scheduling;
using TTask = System.Threading.Tasks.Task;

namespace OneBillElecsnet.Logic.Tasks
{
    class QiwiGetProvidersTask : Task
    {
		private const string ServiceUpdateTaskName = "Qiwi Get Providers Task";
        private const string TaskOwnerName = "OneBillElecsnetService";
        private const int defaultInterval = 60;		
		
		public QiwiGetProvidersTask()
        {
			var ds = new GenDS(OneBill.SettingsProvider.SqlConnectionString);
			DataTable dt = ds.Select("dbo.GetAppSettingByName '{0}'", AppSettingsFieldNames.QiwiTaskIntervalInSeconds);

			TaskName = ServiceUpdateTaskName;
            TaskOwner = TaskOwnerName;
            Routine = ImportRoutine;
            Schedule = G.ValidateDT(dt)
                ? new SecondSchedule(G._I(dt.Rows[0]["FieldValue"]))
                : new SecondSchedule(defaultInterval);
        }

        private async void ImportRoutine()
        {
            if (DP.GetProvidersRequest())
            {
				var ds = new GenDS(OneBill.SettingsProvider.SqlConnectionString);
				DataTable dt = ds.Select("exec dbo.GetAppSettingByName '{0}'",  AppSettingsFieldNames.QiwiApiUrl);

				if (!G.ValidateDT(dt))
					throw new InternalException(LogLevel.DATA_ERROR, TaskOwnerName,
				  "Settings key QiwiApiUrl was not found in DB.");

				HttpClient client = new HttpClient();
                var stringTask = client.GetStringAsync(G._S(dt.Rows[0]["FieldValue"]));
                var msg = await stringTask;

                var options = new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                };

                Provider providerResponse = JsonSerializer.Deserialize<Provider>(msg, options);
				List<Provider> qiwiProviders = providerResponse.ToList();

				DataTable providersFromDB = ds.Select("exec dbo._sp_Providers_GetAll");

				foreach (Provider qp in qiwiProviders)
				{
					var result = ds.Select("exec dbo._sp_Providers_GetByCode '{0}'",qp.ProviderCode);
					if (result.Rows.Count == 0)
					{
						ds.Select("exec dbo._sp_Providers_Insert '{0}', '{1}', {2}, {3}, '{4}', {5}, {6}",
									qp.ProviderCode, qp.Name, qp.Payable, qp.Form, qp.Parents[0], "NULL", (int)ProviderStatus.New);
					}
					else if (result.Rows.Count == 1)
					{
						DataRow row = result.Rows[0];

						if (qp.Name != G._S(row["Name"])
							|| (qp.Form != bool.Parse(G._S(row["Form"])))
							|| qp.Payable != bool.Parse(G._S(row["Payable"]))
							|| qp.Parents[0] != G._S(row["Parents"]))
						{
							ds.Select("exec dbo._sp_Providers_Insert '{0}', '{1}', {2}, {3}, '{4}', {5}, {6}",
									qp.ProviderCode, qp.Name, qp.Payable, qp.Form, qp.Parents[0], "NULL", (int)ProviderStatus.ToRewiew);
						}
					}
					else
					{
						//ToDo if count > 1
					}
				}

                var t = TTask.Run(() =>
                {
                    string time = DateTime.Now.Ticks.ToString();
                    string path = $@"d:\temp\json.{time}.txt";
                    using (FileStream fs = File.Create(path))
                    {
                        byte[] info = new UTF8Encoding(true).GetBytes(msg);
                        fs.Write(info, 0, info.Length);
                    };
                });

                ds.exec("exec SetIsProvidersRequested 0");
            }
        }
    }
}
