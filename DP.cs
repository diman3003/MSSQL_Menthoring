using System;
using System.Data;

namespace OneBill.Data
{
    internal static partial class DP
    {
        public static DataTable LoadTransactionRequests(int count)
        {
            DataTable dt = null;

            try
            {
                GenDS ds = new GenDS(SettingsProvider.SqlConnectionString);
                string sql = string.Format("exec dbo.aggregator_GetTransactionRequests {0}, {1}", (int)RequestTypes.ALL, count);

                dt = ds.Select(sql);
            }
            catch (Exception ex)
            {
                dt = null;
                throw new InternalException(LogLevel.DATA_ERROR,
                  string.Format("DP.LoadTransactionRequests(count = {0})", count),
                  ex.Message);
                //LogProvider.Log( LogLevel.DATA_ERROR , LogTarget.TO_SQL , "DP.LoadTransactionRequests(count)" , ex.Message );

            }

            return dt;
        }

        internal static DataTable LoadRequestForProcessing(int requestId)
        {
            DataTable dt = null;

            try
            {
                GenDS ds = new GenDS(SettingsProvider.SqlConnectionString);
                string sql = string.Format("exec dbo.aggregator_LoadRequestForProcessing {0}", requestId);

                dt = ds.Select(sql);
            }
            catch (Exception ex)
            {
                dt = null;
                throw new InternalException(LogLevel.DATA_ERROR,
                  string.Format("DP.LoadRequestForProcessing(RequestId = {0})", requestId),
                  ex.Message);
                //LogProvider.Log( LogLevel.DATA_ERROR , LogTarget.TO_SQL , "DP.LoadRequestForProcessing()" , ex.Message );

            }

            return dt;
        }

        internal static DataTable LoadSubscriptionRequisites(int SubscriptionId)
        {
            DataTable dt = null;

            try
            {

                GenDS ds = new GenDS(SettingsProvider.SqlConnectionString);
                string sql = string.Format("exec [dbo].[aggregator_LoadSubscriptionRequisites] {0}", SubscriptionId);

                dt = ds.Select(sql);
            }
            catch (Exception ex)
            {
                dt = null;
                throw new InternalException(LogLevel.DATA_ERROR,
                  string.Format("DP.LoadSubscriptionRequisites(SubscriptionId = {0})", SubscriptionId),
                  ex.Message);
                //LogProvider.Log(LogLevel.DATA_ERROR, LogTarget.TO_SQL, "DP.LoadSubscriptionRequisites(subscriptionId)", ex.Message);

            }

            return dt;
        }

        //internal static DataTable LoadMerchantFormats( int MerchantId )
        //{
        //  throw new NotImplementedException();
        //}

        internal static int SaveResponse(int requestId, ResponseInfo responseInfo)
        {
            DataTable dt = null;
            int nRet = 0;

            try
            {

                GenDS ds = new GenDS(SettingsProvider.SqlConnectionString);
                string sql = string.Format("exec [dbo].[aggregator_SaveResponse] {0}, '{1}','{2}','{3}',{4},'{5}'",
                  requestId,
                  responseInfo.MerchantCode,
                  responseInfo.MerchantData.Replace("'", "''"),
                  responseInfo.ResponseCode,
                  responseInfo.PaymentSum.Replace(",", "."),
                  responseInfo.ToString().Replace("'", "''")
                  );

                dt = ds.Select(sql);
                if (G.ValidateDT(dt))
                {
                    nRet = G._I(dt.Rows[0][0]);
                }

            }
            catch (Exception ex)
            {
                dt = null;
                nRet = 0;
                throw new InternalException(LogLevel.DATA_ERROR,
                  string.Format("DP.SaveResponse(RequestId = {0}, Response = {1})", requestId, responseInfo),
                  ex.Message);
                //LogProvider.Log(LogLevel.DATA_ERROR, LogTarget.TO_SQL, "DP.SaveResponse(requestId, response)", ex.Message);

            }

            return nRet;

        }

        internal static void FinalizeRequest(int requestId, string ErrorCode, string ErrorMessage)
        {
            try
            {
                GenDS ds = new GenDS(SettingsProvider.SqlConnectionString);
                string sql = string.Format("exec [dbo].[aggregator_FinalizeRequest] {0}, '{1}','{2}'",
                  requestId, ErrorCode, ErrorMessage.Replace("'", "''")
                  );

                ds.exec(sql);
            }
            catch (Exception ex)
            {
				LogProvider.Log(LogLevel.APP_ERROR, LogTarget.TO_SQL,
				  string.Format("DP.FinalizeRequest(RequestId = {0}, ErrorCode = {1}, ErrorMessage = {2})", requestId, ErrorCode, ErrorMessage),
				  ex.Message);
			}
        }

        internal static DataTable LoadSubscriptionRequisitesByRequestId(int requestId)
        {
            throw new NotImplementedException();
        }

        internal static DataTable LoadRequestData(int requestId)
        {
            DataTable dt = null;

            try
            {
                GenDS ds = new GenDS(SettingsProvider.SqlConnectionString);
                string sql = string.Format("exec dbo.aggregator_LoadRequestData {0}", requestId);

                dt = ds.Select(sql);
            }
            catch (Exception ex)
            {
                dt = null;

                throw new InternalException(LogLevel.DATA_ERROR,
                  string.Format("DP.LoadRequestData(RequestId = {0})", requestId),
                  ex.Message);
            }
            return dt;
        }

		public static void SetServicePingTimePoint()
		{
			try
			{
				var ds = new GenDS(SettingsProvider.SqlConnectionString);
				ds.exec(@"exec [dbo].[SetServicePingTimePoint]");
			}
			catch (Exception ex)
			{
				throw new InternalException(
					LogLevel.DATA_ERROR
					, @"DP.SetServicePingTimePoint"
					, ex.Message
					);
			}
		}

        public static bool GetProvidersRequest()
        {
            try
            {
                var ds = new GenDS(SettingsProvider.SqlConnectionString);
                DataTable dt = ds.Select("Select * from dbo.dc_Settings where Name = 'IsProvidersRequested'");
                bool result = false;

                if (G.ValidateDT(dt) && dt.Rows.Count == 1)
                {
                    var row = dt.Rows[0];
                    result = (G._S(row["Value"]) == "1" || G._S(row["Value"]) == "true");
                }
                else
                {
                    LogProvider.Log(LogLevel.DATA_ERROR, LogTarget.TO_SQL, "ElecsnetService::QIWI::GetProvidersRequest",
                        "Settings not found in DB or key name is not unique.");
                }

                return result;
            }
            catch (Exception ex)
            {
                LogProvider.Log(LogLevel.APP_ERROR, LogTarget.TO_FILE,
                    "ElecsnetService::QIWI::GetProvidersRequest", ex.Message);

                return false;
            }
        }

        public static int PurgeTrace()
		{
			DataTable dt;
            try
            {
				GenDS ds = new GenDS(SettingsProvider.SqlConnectionString);
				dt = ds.Select("dbo.PurgeTrace");
			}
			catch (Exception ex)
			{
				throw new InternalException(LogLevel.DATA_ERROR, "DP.PurgeTrace", ex.Message);
			}

			int result = 0;
			if (dt.Rows.Count > 0)
			{
				result = (int)dt.Rows[0]["Count"];
			}

			return result;
		}
	}
}