using System;
using System.Collections.Generic;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Data.SqlClient;
using System.Data;
using System.Runtime.InteropServices;
using System.Threading;
using System.Configuration;
using System.IO;
using System.Diagnostics;

using log4net;
using log4net.Config;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace FKWeb
{
	public class FKWebCmdTrans
	{
	    private ILog logger = log4net.LogManager.GetLogger("SiteLogger");

	    //private const string CONN_STR = "server=.\\SQLEXPRESS1;uid=golden;pwd=golden5718;database=AttDB";    
	    private const string TBL_CMD_TRANS = "tbl_fkcmd_trans";
	    private const string TBL_CMD_TRANS_BIG_FIELD = "tbl_fkcmd_trans_big_field";
	    private string msDbConn;
	    private bool m_bShowDebugMsg;

	    public FKWebCmdTrans()
	    {
	        const string csFuncName = "Contructor";
	        string strShowDbgMsg;

	        m_bShowDebugMsg = false;
	        strShowDbgMsg = ConfigurationManager.AppSettings["ShowDebugMsg"];
	        strShowDbgMsg.ToLower();
	        if (strShowDbgMsg == "true" || strShowDbgMsg == "yes")
	        {
	            m_bShowDebugMsg = true;
	        }

	        msDbConn = ConfigurationManager.ConnectionStrings["SqlConnFkWeb"].ConnectionString.ToString();
	        PrintDebugMsg(csFuncName, "0 - Conn:" + msDbConn);
	    }

	    public void TestNewtonsoftJsonLib()
	    {
	        string sJson = "{\"fk_name\":\"fk001\",\"fk_time\":\"20141205150420\",\"fk_info\":" +
	            "{" +
	                "\"supported_enroll_data\":[\"FP\",\"PASSWORD\",\"IDCARD\",\"FACE\"]," +
	                "\"fk_bin_data_lib\":\"fk_bin_data_1001\"," +
	                "\"firmware\":\"FK725HS001\"" +
	            "}" +
	        "}";

	        JObject jobjTest = JObject.Parse(sJson);
	        string sDevName = jobjTest["fk_name"].ToString();
	        string sDevTime = jobjTest["fk_time"].ToString();
	        string sDevInfo = jobjTest["fk_info"].ToString(Formatting.None);

            JObject jobjSend = new JObject();

            jobjSend.Add("response_code", "OK");
            jobjSend.Add("trans_id", "123");
            jobjSend.Add("cmd_code", "AA_BB");
            jobjSend.Add("cmd_param", JObject.Parse("{\"time\":\"123456\"}"));

            string sSend = jobjSend.ToString(Formatting.None);
            sSend = Newtonsoft.Json.JsonConvert.SerializeObject(jobjSend, Formatting.None);
	    }

	    public void TestStoredProcedureBinData()
	    {
	        const string csFuncName = "TestStoredProcedureBinData";

	        PrintDebugMsg(csFuncName, "0 - Start");

	        try
	        {
	            byte[] bytCmdResult = new byte[12000];
	            bytCmdResult[0] = 3;
	            bytCmdResult[1] = 3;

	            bytCmdResult[11998] = 5;
	            bytCmdResult[11999] = 5;

	            SqlConnection conn = new SqlConnection(msDbConn);
	            conn.Open();

	            PrintDebugMsg(csFuncName, "1");

	            SqlCommand sqlCmd = new SqlCommand("usp_test_bin_1", conn);
	            sqlCmd.CommandType = CommandType.StoredProcedure;

	            sqlCmd.Parameters.Add("@trans_id", SqlDbType.VarChar).Value = "tr002";
	            sqlCmd.Parameters.Add("@dev_id", SqlDbType.VarChar).Value = "dv002";
	            
	            SqlParameter sqlParamCmdResult = new SqlParameter("@cmd_result", SqlDbType.VarBinary);
	            sqlParamCmdResult.Direction = ParameterDirection.Input;
	            sqlParamCmdResult.Size = bytCmdResult.Length;
	            sqlParamCmdResult.Value = bytCmdResult;
	            sqlCmd.Parameters.Add(sqlParamCmdResult);

	            sqlCmd.ExecuteNonQuery();
	            sqlCmd.Dispose();

	            PrintDebugMsg(csFuncName, "2");

	            sqlCmd = new SqlCommand("usp_test_bin_2", conn);
	            sqlCmd.CommandType = CommandType.StoredProcedure;

	            sqlCmd.Parameters.Add("@trans_id", SqlDbType.VarChar).Value = "tr002";
	            sqlCmd.Parameters.Add("@dev_id", SqlDbType.VarChar).Value = "dv002";
	            
	            sqlParamCmdResult = sqlCmd.Parameters.Add("@cmd_result", SqlDbType.VarBinary);
	            // 바이너리자료를 출력하는 파라메터로부터 출력된 자료를 얻으려면
	            //  SqlParameter 오브젝트의 Size를 -1로 설정하여야 한다.
	            sqlParamCmdResult.Size = -1;            
	            sqlParamCmdResult.Direction = ParameterDirection.Output;
	            
	            sqlCmd.ExecuteNonQuery();
	            
	            PrintDebugMsg(csFuncName, "3");

	            bytCmdResult = (byte[])sqlParamCmdResult.Value;

	            PrintDebugMsg(csFuncName, "4 - " +
	                Convert.ToString(bytCmdResult[0]) + ", " +
	                Convert.ToString(bytCmdResult[1]) + ", " +
	                Convert.ToString(bytCmdResult[11998]) + ", " +
	                Convert.ToString(bytCmdResult[11999]));
	            
	            sqlCmd.Dispose();

	            PrintDebugMsg(csFuncName, "5");

	            conn.Close();
	        }
	        catch (Exception e)
	        {
	            PrintDebugMsg(csFuncName, "except - " + e.ToString());
	            return;
	        }
	    }

	    public void Test()
	    {
	        const string csFuncName = "Test";

	        string strJson;

	        PrintDebugMsg(csFuncName, "0 - Start");

	        try
	        {
	            SqlConnection conn = new SqlConnection(msDbConn);
	            conn.Open();
	            conn.Close();
	        }
	        catch (Exception e)
	        {
	            PrintDebugMsg(csFuncName, "1 - " + e.ToString());
	            return;
	        }

	        strJson = "{abc:12345,fgh:quit,k1k:7896}";
	        if (FKWebTools.GetFieldValueInJSONString(strJson, "fgh") != "quit")
	        {
	            PrintDebugMsg(csFuncName, "Error - Json parser");
	            return;
	        }
	        if (FKWebTools.GetFieldValueInJSONString(strJson, "k1k") != "7896")
	        {
	            PrintDebugMsg(csFuncName, "Error - Json parser");            
	            return;
	        }

	        if (FKWebTools.ConvertFKTimeToNormalTimeString("20121213140123") != "2012-12-13 14:01:23")
	        {
	            PrintDebugMsg(csFuncName, "Error - FK time string convert");
	            return;
	        }

	        if (FKWebTools.GetFKTimeString14(Convert.ToDateTime("2013-2-3 19:7:29")) != "20130203190729")
	        {
	            PrintDebugMsg(csFuncName, "Error - time to FKTime14 convert");
	            return;
	        }

	        PrintDebugMsg(csFuncName, "OK - End");
	    }

	    public void PrintDebugMsg(string astrFunction, string astrMsg)
	    {
	        if (!m_bShowDebugMsg)
	            return;

	        logger.Info(astrFunction + " -- " + astrMsg);
	        FKWebTools.PrintDebug(astrFunction, astrMsg);
	    }

	    public string InsertGLog(string astrDevId, string astrGLog)
	    {
	        string strEnrollId;
	        string strVerifyMode;
	        string strIoMode;
	        string strIoTime;

	        strEnrollId = FKWebTools.GetFieldValueInJSONString(astrGLog, "enroll_id");
	        strVerifyMode = FKWebTools.GetFieldValueInJSONString(astrGLog, "verify_mode");
	        strIoMode = FKWebTools.GetFieldValueInJSONString(astrGLog, "io_mode");
	    
	        strIoTime = FKWebTools.GetFieldValueInJSONString(astrGLog, "io_time");
	        strIoTime = FKWebTools.ConvertFKTimeToNormalTimeString(strIoTime);

	        try
	        {
	            if (!FKWebTools.IsValidEngDigitString(strEnrollId, 24))
	                return "{result:ERROR_INVALID_PARAM_ENROLL_ID}";
	            if (String.IsNullOrEmpty(strVerifyMode) || strVerifyMode.Length > 8)
	                return "{result:ERROR_INVALID_PARAM_VERIFY_MODE}";
	            if (String.IsNullOrEmpty(strIoMode) || strIoMode.Length > 8)
	                return "{result:ERROR_INVALID_PARAM_IO_MODE}";
	            if (!FKWebTools.IsValidTimeString(strIoTime))
	                return "{result:ERROR_INVALID_PARAM_IO_TIME}";
	        }
	        catch (Exception)
	        {
	            return "{result:ERROR_INVALID_PARAM}";
	        }

	        try
	        {
	            string strSql;
	            SqlConnection conn = new SqlConnection(msDbConn);
	            conn.Open();

	            strSql = "INSERT INTO tbl_realtime_glog";
	            strSql = strSql + "(update_time, device_id, enroll_id, verify_mode, io_mode, io_time)";
	            strSql = strSql + "VALUES('" + FKWebTools.TimeToString(DateTime.Now) + "', ";
	            strSql = strSql + "'" + astrDevId + "', ";
	            strSql = strSql + "'" + strEnrollId + "', ";
	            strSql = strSql + "'" + strVerifyMode + "', ";
	            strSql = strSql + "'" + strIoMode + "', ";
	            strSql = strSql + "'" + strIoTime + "')";
	            
	            SqlCommand cmd = new SqlCommand(strSql, conn);
	            cmd.ExecuteNonQuery();
	            conn.Close();

	            return "{result:OK}";
	        }
	        catch (Exception)
	        {
	            
	            return "{result:ERROR_DB_ACCESS}";
	        }
	    }

	    public string InsertEnrollData(string astrDevId, string astrEnrollData)
	    {
	        string strEnrollId;
	        string strBackupNumber;
	        string strUserPrivilege;
	        string strFpData;
	        string strPassword;
	        string strIdCard;

	        int nBackupNumber;

	        strEnrollId = FKWebTools.GetFieldValueInJSONString(astrEnrollData, "enroll_id");
	        strBackupNumber = FKWebTools.GetFieldValueInJSONString(astrEnrollData, "backup_number");
	        strUserPrivilege = FKWebTools.GetFieldValueInJSONString(astrEnrollData, "user_privilege");
	        strFpData = FKWebTools.GetFieldValueInJSONString(astrEnrollData, "fp_data");
	        strPassword = FKWebTools.GetFieldValueInJSONString(astrEnrollData, "password");
	        strIdCard = FKWebTools.GetFieldValueInJSONString(astrEnrollData, "idcard");

	        try
	        {
	            if (!FKWebTools.IsValidEngDigitString(strEnrollId, 24))
	                return "{result:ERROR_INVALID_PARAM_ENROLL_ID}";
	            
	            nBackupNumber = Convert.ToInt32(strBackupNumber);
	            if (nBackupNumber < 0 || nBackupNumber > 12)
	                return "{result:ERROR_INVALID_PARAM_BACKUP_NUMBER}";
	        }
	        catch (Exception)
	        {
	            return "{result:ERROR_INVALID_PARAM}";
	        }

	        try
	        {
	            string strSql;
	            SqlConnection conn = new SqlConnection(msDbConn);
	            conn.Open();

	            strSql = "INSERT INTO tbl_realtime_enroll_data";
	            strSql = strSql + "(update_time, device_id, enroll_id, backup_number, user_privilege, fp_data, password, idcard)";
	            strSql = strSql + "VALUES('" + FKWebTools.TimeToString(DateTime.Now) + "', ";
	            strSql = strSql + "'" + astrDevId + "', ";
	            strSql = strSql + "'" + strEnrollId + "', ";
	            strSql = strSql + "'" + nBackupNumber + "', ";
	            strSql = strSql + "'" + strUserPrivilege + "', ";
	            strSql = strSql + "'" + strFpData + "', ";
	            strSql = strSql + "'" + strPassword + "', ";
	            strSql = strSql + "'" + strIdCard + "')";

	            SqlCommand cmd = new SqlCommand(strSql, conn);
	            cmd.ExecuteNonQuery();
	            conn.Close();

	            return "{result:OK}";
	        }
	        catch (Exception)
	        {
	            return "{result:ERROR_DB_ACCESS}";
	        }
	    }

	    // 기대의 접속상태표를 갱신한다.
	    public void UpdateFKDeviceStatus(
	        SqlConnection asqlConn,
	        string asDevId,
	        string asDevName,
	        string asDevTime,
	        string asDevInfo)
	    {
	        const string csFuncName = "UpdateFKDeviceStatus";

	        PrintDebugMsg(csFuncName, "0 - DevTime:" + asDevTime + ", DevId:" + asDevId + ", DevName:" + asDevName);

	        if (asqlConn.State != ConnectionState.Open)
	            return;

	        try
	        {
	            PrintDebugMsg(csFuncName, "1");

	            SqlCommand sqlCmd = new SqlCommand("usp_update_device_conn_status", asqlConn);
	            sqlCmd.CommandType = CommandType.StoredProcedure;
	            sqlCmd.Parameters.Add("@dev_id", SqlDbType.VarChar).Value = asDevId;
	            sqlCmd.Parameters.Add("@dev_name", SqlDbType.VarChar).Value = asDevName;
	            sqlCmd.Parameters.Add("@tm_last_update", SqlDbType.DateTime).Value = DateTime.Now;
	            sqlCmd.Parameters.Add("@fktm_last_update", SqlDbType.DateTime).Value = FKWebTools.ConvertFKTimeToNormalTimeString(asDevTime);
	            sqlCmd.Parameters.Add("@dev_info", SqlDbType.VarChar).Value = asDevInfo;

	            sqlCmd.ExecuteNonQuery();

	            PrintDebugMsg(csFuncName, "2");
	        }
	        catch (Exception e)
	        {
	            PrintDebugMsg(csFuncName, "Except - 1 - " + e.ToString());            
	        }
	    }
	    
	    public bool CheckResetCmd(
	        SqlConnection asqlConn, 
	        string asDevId, 
	        out string asTransId)
	    {
	        const string csFuncName = "CheckResetCmd";
	        string sTransId = "";
	        
	        PrintDebugMsg(csFuncName, "0 - dev_id:" + asDevId);

	        asTransId = "";
	        
	        if (asqlConn.State != ConnectionState.Open)
	            return false;

	        try
	        {
	            PrintDebugMsg(csFuncName, "1");

	            SqlCommand sqlCmd = new SqlCommand("usp_check_reset_fk_cmd", asqlConn);
	            sqlCmd.CommandType = CommandType.StoredProcedure;
	            
	            sqlCmd.Parameters.Add("@dev_id", SqlDbType.VarChar).Value = asDevId;
	            
	            SqlParameter sqlParamTransId = new SqlParameter("@trans_id", SqlDbType.VarChar);
	            sqlParamTransId.Direction = ParameterDirection.Output;
	            sqlParamTransId.Size = 16;
	            sqlCmd.Parameters.Add(sqlParamTransId);

	            sqlCmd.ExecuteNonQuery();
	            sTransId = Convert.ToString(sqlCmd.Parameters["@trans_id"].Value);
	            sqlCmd.Dispose();

	            PrintDebugMsg(csFuncName, "2 - trans_id:" + sTransId);
	            
	            if (sTransId.Length == 0)
	            {
	                PrintDebugMsg(csFuncName, "3");                
	                return false;
	            }
	            else
	            {
	                asTransId = sTransId;
	                PrintDebugMsg(csFuncName, "4 - reset fk - " + asTransId);
	                return true;
	            }
	        }
	        catch (Exception e)
	        {
	            PrintDebugMsg(csFuncName, "Except - 1 - " + e.ToString());
	            return false;
	        }
	    }

	    public void MakeSetTimeCmdParam(string asCmdCode, ref string asCmdParam)
	    {
	        if (asCmdCode != "SET_TIME")
	            return;

	        asCmdParam = "{\"time\":\"" + FKWebTools.GetFKTimeString14(DateTime.Now) + "\"}";
	    }

	    public void MakeSetTimeCmdParamBin(string asCmdCode, out byte[] abytCmdParam)
	    {
	        abytCmdParam = new byte[0];

	        if (asCmdCode != "SET_TIME")
	            return;

	        string sCmdParam = "{\"time\":\"" + FKWebTools.GetFKTimeString14(DateTime.Now) + "\"}";
	        CreateBSCommBufferFromString(sCmdParam, out abytCmdParam);
	    }

	    // BS통신에 리용되는 바퍼로부터 문자렬에 해당한 부분을 읽어내여 그 문자렬을 복귀한다.
	    public string GetStringFromBSCommBuffer(byte[] abytBuffer)
	    {
	        if (abytBuffer.Length < 4)
	            return "";

	        try
	        {
	            int lenText = BitConverter.ToInt32(abytBuffer, 0);
	            if (lenText > abytBuffer.Length - 4)
	                return "";

                if (lenText == 0)
                    return "";
                
                return System.Text.Encoding.UTF8.GetString(abytBuffer, 4, lenText);
	        }
	        catch
	        {
	            return "";
	        }
	    }

	    public void GetStringAndBinaryFromBSCommBuffer(
	        byte[] abytBSCommBuffer,
	        out string asString, 
	        out byte [] abytBinary)
	    {
	        asString = "";
	        abytBinary = new byte[0];

	        if (abytBSCommBuffer.Length < 4)
	            return;

	        try
	        {
	            int lenText = BitConverter.ToInt32(abytBSCommBuffer, 0);
	            if (lenText > abytBSCommBuffer.Length - 4)
	                return;

                if (lenText > 0)
                {
                    asString = System.Text.Encoding.UTF8.GetString(abytBSCommBuffer, 4, lenText);
                }
                
	            int lenBin = abytBSCommBuffer.Length - lenText - 4;
                if (lenBin < 1)
                    return;

                abytBinary = new byte [lenBin];
	            Buffer.BlockCopy(
	                abytBSCommBuffer, lenText + 4, 
	                abytBinary, 0, 
	                lenBin);
	            return;
	        }
	        catch
	        {
	            return;
	        }
	    }

	    public bool CreateBSCommBufferFromString(string asCmdParamText, out byte[] abytBuffer)
	    {
	        abytBuffer = new byte[4];
            Array.Clear(abytBuffer, 0, 4);

	        try
	        {
	            if (asCmdParamText.Length == 0)
	                return true;

	            // 문자렬자료를 바이트배렬로 변환하고 마지막에 0을 붙인다. 그리고 그 길이를 문자렬자료길이로 본다.
	            // 전송할 파라메터바이트배렬의 첫 4바이트는 문자렬자료의 길이를 나타낸다.
	            byte[] bytText = System.Text.Encoding.UTF8.GetBytes(asCmdParamText);
	            byte[] bytTextLen = BitConverter.GetBytes(Convert.ToUInt32(bytText.Length + 1));
	            abytBuffer = new byte[4 + bytText.Length + 1];
	            bytTextLen.CopyTo(abytBuffer, 0);
	            bytText.CopyTo(abytBuffer, 4);
	            abytBuffer[4 + bytText.Length] = 0;
	            return true;
	        }
	        catch
	        {
                abytBuffer = new byte[4];
                Array.Clear(abytBuffer, 0, 4);
	            return false;
	        }
	    }

	    // 기대가 자기에 대해 발행된 조작자지령을 얻어갈때 호출되는 함수이다.
	    public void ReceiveCmd(
	        string asDevId,
	        string asDevName,
	        string asDevTime, 
	        string asDevInfo,
	        out string asResponseCode,
	        out string asTransId,
	        out string asCmdCode,
	        out byte [] abytCmdParamBin)
	    {
	        const string csFuncName = "ReceiveCmd";

	        asResponseCode = "ERROR";
	        asTransId = "";
	        asCmdCode = "";
	        abytCmdParamBin = new byte[0];

	        SqlConnection sqlConn = null;

	        PrintDebugMsg(csFuncName, "0 - Start");

	        try
	        {
	            sqlConn = new SqlConnection(msDbConn);
	            sqlConn.Open();
	            PrintDebugMsg(csFuncName, "1 - Db connected");
	        }
	        catch (Exception e)
	        {
	            PrintDebugMsg(csFuncName, "Error - Not connected to db" + e.ToString() + ", ConnString=" + sqlConn.ConnectionString);
	            sqlConn.Close();
	            asResponseCode = "ERROR_DB_CONNECT";
	            return;
	        }

	        PrintDebugMsg(csFuncName, "2");
	        
	        // "기대재기동"지령이 발행된것이 있으면 그것을 기대로 내려보낸다.
	        if (CheckResetCmd(sqlConn, asDevId, out asTransId))
	        {
	            PrintDebugMsg(csFuncName, "2.1 - " + asTransId);
	            sqlConn.Close();
	            asResponseCode = "RESET_FK";
	            return;
	        }

	        PrintDebugMsg(csFuncName, "3");
	        
	        // 기대의 련결상태를 갱신한다.
	        UpdateFKDeviceStatus(sqlConn, asDevId, asDevName, asDevTime, asDevInfo);

	        // 기대에 대해 발행된 조작자지령이 있으면 그것을 기대로 내려보낸다.
	        try
	        {
	            PrintDebugMsg(csFuncName, "4");

	            SqlCommand sqlCmd = new SqlCommand("usp_receive_cmd", sqlConn);
	            sqlCmd.CommandType = CommandType.StoredProcedure;
	            
	            sqlCmd.Parameters.Add("@dev_id", SqlDbType.VarChar).Value = asDevId;
	            
	            SqlParameter sqlParamTransId = new SqlParameter("@trans_id", SqlDbType.VarChar);
	            sqlParamTransId.Direction = ParameterDirection.Output;
	            sqlParamTransId.Size = 16;
	            sqlCmd.Parameters.Add(sqlParamTransId);
	            
	            SqlParameter sqlParamCmdCode = new SqlParameter("@cmd_code", SqlDbType.VarChar);
	            sqlParamCmdCode.Direction = ParameterDirection.Output;
	            sqlParamCmdCode.Size = 32;
	            sqlCmd.Parameters.Add(sqlParamCmdCode);
	            
	            SqlParameter sqlParamCmdParamBin = new SqlParameter("@cmd_param_bin", SqlDbType.VarBinary);
	            sqlParamCmdParamBin.Direction = ParameterDirection.Output;
	            sqlParamCmdParamBin.Size = -1;
	            sqlCmd.Parameters.Add(sqlParamCmdParamBin);

	            sqlCmd.ExecuteNonQuery();

	            PrintDebugMsg(csFuncName, "5");
	            
	            asTransId = Convert.ToString(sqlCmd.Parameters["@trans_id"].Value);            
	            if (asTransId.Length == 0)
	            {
	                PrintDebugMsg(csFuncName, "5 - no cmd");
	                asResponseCode = "ERROR_NO_CMD";
	            }
	            else
	            {
	                asResponseCode = "OK";
	                asCmdCode = Convert.ToString(sqlCmd.Parameters["@cmd_code"].Value);

	                if (sqlParamCmdParamBin.Value.GetType().IsArray)
	                    abytCmdParamBin = (byte[])sqlParamCmdParamBin.Value;

	                PrintDebugMsg(csFuncName, "6 - trans_id:" + asTransId + "cmd_code:" + asCmdCode);
	                
	                // 만일 "기대시간동기"지령이 발행된것이 발견되면 동기시킬 시간을 써버의 시간으로 설정한다.
	                MakeSetTimeCmdParamBin(asCmdCode, out abytCmdParamBin);
	            }
	            
	            sqlCmd.Dispose();

	            PrintDebugMsg(csFuncName, "11");
	            sqlConn.Close();
	            return;
	        }
	        catch (Exception e)
	        {
	            PrintDebugMsg(csFuncName, "Except - 1 - " + e.ToString());
	            sqlConn.Close();

	            asResponseCode = "ERROR";
	            asTransId = "";
	            asCmdCode = "";
	            abytCmdParamBin = new byte[0];
	        }
	    }

	    // 기대가 조작자지령을 접수하고 올려보내는 결과를 받을때 호출되는 함수이다.
	    public void SetCmdResult(
	        string asTransId, 
	        string asDevId, 
	        string asCmdCode, 
	        string asCmdResult,
	        out string asResponseCode)
	    {
	        const string csFuncName = "SetCmdResult";
	        string sTransId = "";
	        string sSql;

	        SqlConnection sqlConn = null;
	        SqlTransaction sqlTrans = null;
	        bool bIsTransStart = false;

	        PrintDebugMsg(csFuncName, "0 - trans_id:" + asTransId + ", dev_id:" + asDevId);

	        try
	        {
	            sqlConn = new SqlConnection(msDbConn);
	            sqlConn.Open();
	        }
	        catch (Exception)
	        {
	            PrintDebugMsg(csFuncName, "Error - Not connected db");
	            sqlConn.Close();
	            asResponseCode = "ERROR_DB_CONNECT";
	            return;
	        }

	        // "기대재기동"지령이 발행된것이 있으면 그것을 기대로 내려보낸다.
	        if (CheckResetCmd(sqlConn, asDevId, out sTransId))
	        {
	            PrintDebugMsg(csFuncName, "1 - " + sTransId);
	            sqlConn.Close();
	            asResponseCode = "RESET_FK";
	            return;
	        }

	        try
	        {
	            sqlTrans = sqlConn.BeginTransaction();
	            bIsTransStart = true;

	            sSql = "UPDATE tbl_fkcmd_trans SET cmd_result='" + asCmdResult + "', status='RESULT', update_time='" + FKWebTools.TimeToString(DateTime.Now) + "'";
	            sSql = sSql + " WHERE trans_id='" + asTransId + "' AND device_id='" + asDevId + "'";
	            sSql = sSql + " AND status='RUN'";

	            PrintDebugMsg(csFuncName, "2 - " + sSql);

	            SqlCommand sqlCmd = new SqlCommand(sSql, sqlConn, sqlTrans);
	            sqlCmd.ExecuteNonQuery();
	            sqlTrans.Commit();
	            bIsTransStart = false;
	            sqlConn.Close();

	            PrintDebugMsg(csFuncName, "3");

	            asResponseCode = "OK";
	            return;
	        }
	        catch (Exception e)
	        {
	            PrintDebugMsg(csFuncName, "Except - 1 - " + e.ToString());
	            if (bIsTransStart)
	                sqlTrans.Rollback();

	            bIsTransStart = false;
	            sqlConn.Close();
	            asResponseCode = "ERROR_DB_ACCESS";
	            
	            PrintDebugMsg(csFuncName, "Except - 2");            
	            return;
	        }        
	    }

	    // 기대가 조작자지령을 수행한 결과를 올려보낼때 큰 길이의 필드가 있는 경우 호출되는 함수이다.
	    /*
	    public string SetCmdBigField(
	        string astrTransId,
	        string astrDevId,
	        string astrFieldName,
	        int anBlockId,
	        string astrBlockData)
	    {
	        const string csFuncName = "SetCmdBigField";
	        string strRet = "";
	        SqlConnection sqlConn = null;

	        PrintDebugMsg(csFuncName, "0 - trans_id:" + astrTransId + ", dev_id:" + astrDevId + ", field:" + astrFieldName + ", blk_id:" + anBlockId);
	        
	        try
	        {
	            sqlConn = new SqlConnection(msDbConn);
	            sqlConn.Open();
	        }
	        catch (Exception)
	        {
	            PrintDebugMsg(csFuncName, "Error - Not connected db");
	            sqlConn.Close();
	            return "{result:ERROR_DB_CONNECT}";
	        }

	        PrintDebugMsg(csFuncName, "1");

	        // "기대재기동"지령이 발행된것이 있으면 그것을 기대로 내려보낸다.
	        if (CheckResetCmd(sqlConn, astrDevId, ref strRet))
	        {
	            PrintDebugMsg(csFuncName, "1.1 - " + strRet);
	            sqlConn.Close();
	            return strRet;
	        }

	        try
	        {
	            PrintDebugMsg(csFuncName, "2");

	            int nNextBlkId = 0;
	            SqlCommand sqlCmd = new SqlCommand("usp_set_cmd_result_big_field", sqlConn);
	            sqlCmd.CommandType = CommandType.StoredProcedure;

	            sqlCmd.Parameters.Add("@trans_id", SqlDbType.VarChar).Value = astrTransId;
	            sqlCmd.Parameters.Add("@dev_id", SqlDbType.VarChar).Value = astrDevId;
	            sqlCmd.Parameters.Add("@result_field_name", SqlDbType.VarChar).Value = astrFieldName;
	            sqlCmd.Parameters.Add("@blk_id", SqlDbType.Int).Value = anBlockId;
	            sqlCmd.Parameters.Add("@blk_data", SqlDbType.VarChar).Value = astrBlockData;

	            SqlParameter sqlParamNextBlkId = new SqlParameter("@next_blk_id", SqlDbType.Int);
	            sqlParamNextBlkId.Direction = ParameterDirection.Output;
	            sqlCmd.Parameters.Add(sqlParamNextBlkId);

	            PrintDebugMsg(csFuncName, "3");
	            sqlCmd.ExecuteNonQuery();
	            nNextBlkId = Convert.ToInt32(sqlCmd.Parameters["@next_blk_id"].Value);
	            sqlCmd.Dispose();
	            sqlConn.Close();

	            if (nNextBlkId < 1)
	            {
	                PrintDebugMsg(csFuncName, "4");
	                strRet = "{result:ERROR_INVALID_BLOCK,trans_id:" + astrTransId + ",blk_id:" + anBlockId + "}";                
	                return strRet;
	            }
	            else
	            {
	                PrintDebugMsg(csFuncName, "5");
	                strRet = "{result:OK,trans_id:" + astrTransId + ",result_field_name:" + astrFieldName + ",blk_id:" + anBlockId + "}";                
	                return strRet;
	            }
	        }
	        catch (Exception e)
	        {
	            PrintDebugMsg(csFuncName, "Except - 1 - " + e.ToString());
	            strRet = "{result:ERROR,trans_id:" + astrTransId + ",blk_id:" + anBlockId + "}";
	            sqlConn.Close();
	            return strRet;
	        }
	    }
	    */

	    // 기대가 조작자지령을 접수할때 큰 길이의 필드가 있는 경우 호출되는 함수이다.
	    /*
	    public string GetCmdBigField(
	        string astrTransId,
	        string astrDevId,
	        string astrFieldName,
	        int anBlockId)
	    {
	        const string csFuncName = "GetCmdBigField";
	        string strRet = "";
	        SqlConnection sqlConn = null;

	        PrintDebugMsg(csFuncName, "0 - trans_id:" + astrTransId + ", dev_id:" + astrDevId + ", field:" + astrFieldName + ", blk_id:" + anBlockId);

	        try
	        {
	            sqlConn = new SqlConnection(msDbConn);
	            sqlConn.Open();
	        }
	        catch (Exception)
	        {
	            PrintDebugMsg(csFuncName, "Error - Not connected db");            
	            strRet = "{result:ERROR_DB_CONNECT,trans_id:" + astrTransId + ",blk_id:" + anBlockId + "}";
	            sqlConn.Close();
	            return strRet;
	        }

	        PrintDebugMsg(csFuncName, "1");

	        // "기대재기동"지령이 발행된것이 있으면 그것을 기대로 내려보낸다.
	        if (CheckResetCmd(sqlConn, astrDevId, ref strRet))
	        {
	            sqlConn.Close();
	            return strRet;
	        }

	        try
	        {
	            PrintDebugMsg(csFuncName, "2");

	            int nNextBlkId = 0;
	            string strBlockData = "";

	            SqlCommand sqlCmd = new SqlCommand("usp_get_cmd_param_big_field", sqlConn);
	            sqlCmd.CommandType = CommandType.StoredProcedure;

	            sqlCmd.Parameters.Add("@trans_id", SqlDbType.VarChar).Value = astrTransId;
	            sqlCmd.Parameters.Add("@dev_id", SqlDbType.VarChar).Value = astrDevId;
	            sqlCmd.Parameters.Add("@param_field_name", SqlDbType.VarChar).Value = astrFieldName;
	            sqlCmd.Parameters.Add("@blk_id", SqlDbType.Int).Value = anBlockId;

	            SqlParameter sqlParamBlockData = new SqlParameter("@blk_data", SqlDbType.VarChar);
	            sqlParamBlockData.Direction = ParameterDirection.Output;
	            sqlParamBlockData.Size = 1500;
	            sqlCmd.Parameters.Add(sqlParamBlockData);

	            SqlParameter sqlParamNextBlkId = new SqlParameter("@next_blk_id", SqlDbType.Int);
	            sqlParamNextBlkId.Direction = ParameterDirection.Output;
	            sqlCmd.Parameters.Add(sqlParamNextBlkId);

	            PrintDebugMsg(csFuncName, "3");
	            sqlCmd.ExecuteNonQuery();
	            strBlockData = Convert.ToString(sqlCmd.Parameters["@blk_data"].Value);
	            nNextBlkId = Convert.ToInt32(sqlCmd.Parameters["@next_blk_id"].Value);
	            sqlCmd.Dispose();
	            sqlConn.Close();

	            if (nNextBlkId < 0)
	            {
	                PrintDebugMsg(csFuncName, "4");
	                strRet = "{result:ERROR_BLOCK_READ,trans_id:" + astrTransId + ",param_field_name:" + astrFieldName + ",blk_id:" + anBlockId + "}";
	                return strRet;
	            }
	            else if (nNextBlkId == 0)
	            {
	                PrintDebugMsg(csFuncName, "5");
	                strRet = "{result:OK_END,trans_id:" + astrTransId
	                    + ",param_field_name:" + astrFieldName
	                    + ",blk_id:" + anBlockId
	                    + ",blk_len:" + strBlockData.Length
	                    + ",blk_data:" + strBlockData;
	                return strRet;
	            }
	            else
	            {
	                PrintDebugMsg(csFuncName, "6");
	                strRet = "{result:OK,trans_id:" + astrTransId
	                    + ",param_field_name:" + astrFieldName
	                    + ",blk_id:" + anBlockId
	                    + ",blk_len:" + strBlockData.Length
	                    + ",blk_data:" + strBlockData;
	                return strRet;
	            }
	        }
	        catch (Exception e)
	        {
	            PrintDebugMsg(csFuncName, "Except - 1 - " + e.ToString());
	            strRet = "{result:ERROR,trans_id:" + astrTransId + ",blk_id:" + anBlockId + "}";
	            sqlConn.Close();
	            return strRet;
	        }
	    }
	    */
	}
}