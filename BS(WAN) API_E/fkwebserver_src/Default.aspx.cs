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

using FKWeb;

public class FKWebTransBlockData
{
    public int LastBlockNo;
    public DateTime TmLastModified;
    public MemoryStream MemStream;
}

public partial class _Default : System.Web.UI.Page
{
    ILog logger = log4net.LogManager.GetLogger("SiteLogger");
    //ILog logger = log4net.LogManager.GetLogger("DebugOutLogger");

    private const string REQ_CODE_RECV_CMD = "receive_cmd";
    private const string REQ_CODE_SEND_CMD_RESULT = "send_cmd_result";
    private const string REQ_CODE_REALTIME_GLOG = "realtime_glog";
    private const string REQ_CODE_REALTIME_ENROLL = "realtime_enroll_data";
    private const string REQ_CODE_REALTIME_DOOR = "realtime_door_status";
    //private const string REQ_CODE_REALTIME_SLOG = "realtime_slog";
    private string TRANSIDKEY = FKWebCmdTrans.REQUEST_HEADER_KEY_TRANSID;

    protected int GetRequestStreamBytes(
        out byte[] abytReceived)
    {
        abytReceived = new byte[0];
        int lenContent = Convert.ToInt32((string)Request.Headers["Content-Length"]);
        if (lenContent < 1)
            return 0;

        Stream streamIn = Request.InputStream;
        byte[] bytRecv = new byte[lenContent];
        int lenRead;
        lenRead = streamIn.Read(bytRecv, 0, lenContent);
        if (lenRead != lenContent)
        {
            // 만일 읽어야 할 길이만큼 다 읽지 못하면
            return -1;
        }

        abytReceived = bytRecv;
        return lenContent;
    }

    protected void SendResponseToClient(
        string asResponseCode,
        string asTransId,
        string asCmdCode,
        byte[] abytCmdParam)
    {
        Response.AddHeader("response_code", asResponseCode);
        Response.AddHeader(TRANSIDKEY, asTransId);
        Response.AddHeader("cmd_code", asCmdCode);

        Response.ContentType = "application/octet-stream";
        Response.AddHeader("Content-Length", Convert.ToString(abytCmdParam.Length));
        Response.Flush();

        if (abytCmdParam.Length > 0)
        {
            Stream streamOut = Response.OutputStream;
            streamOut.Write(abytCmdParam, 0, abytCmdParam.Length);
            streamOut.Close();
        }
    }

    protected void OnReceiveCmd(FKWebCmdTrans aCmdTrans, string asDevId, string asTransId, byte[] abytReuest)
    {
        const string csFuncName = "Page_Load - receive_cmd";

        string sRequest;
        string sResponse;
        string sTransId = asTransId;
        byte[] bytRequest = abytReuest;
        string sCmdCode;

        try
        {
            aCmdTrans.PrintDebugMsg(csFuncName, "2");

            if (aCmdTrans.DevModel == null)
                sRequest = FKWebCmdTrans.GetStringFromBSCommBuffer(bytRequest);
            else
                sRequest = System.Text.Encoding.UTF8.GetString(bytRequest);
            if (sRequest.Length == 0)
            {
                // 만일 지령접수요구로 올라온 문자렬의 길이가 0이면
                //  잘못된 요구가 올라온것으로 보고 접속을 차단한다.
                Response.Close();
                return;
            }

            // 지령접수요구가 올라올때 기대이름, 기대시간, 기대정보가
            //  body부분에 포함되여 올라오게 되여있다.
            string sDevName;
            string sDevTime;
            string sDevInfo;

            JObject jobjRequest = JObject.Parse(sRequest);
            sDevName = jobjRequest["fk_name"].ToString();
            sDevTime = jobjRequest["fk_time"].ToString();
            sDevInfo = jobjRequest["fk_info"].ToString(Newtonsoft.Json.Formatting.None);

            aCmdTrans.PrintDebugMsg(csFuncName, "3 - DevName=" + sDevName + ", DevTime=" + sDevTime + ", DevInfo=" + sDevInfo);

            byte[] bytCmdParam = new byte[0];
            aCmdTrans.ReceiveCmd(asDevId, sDevName, sDevTime, sDevInfo,
                                out sResponse, out sTransId, out sCmdCode, out bytCmdParam);

            aCmdTrans.PrintDebugMsg(csFuncName, "4");

            SendResponseToClient(
                sResponse,
                sTransId,
                sCmdCode,
                bytCmdParam);

            aCmdTrans.PrintDebugMsg(csFuncName, "5");
        }
        catch (Exception ex)
        {
            aCmdTrans.PrintDebugMsg(csFuncName, "Except - 1 - " + ex.ToString());
            // 지령접수처리과정에 exception이 발생하면 접속을 차단한다.                
            Response.Close();
            return;
        }
    }

    // 지령수행결과로 올라오는 블로크자료들을 기대별로 할당한 메모리스트림에 추가한다.
    protected int AddBlockData(string asDevId, int anBlkNo, byte[] abytBlkData)
    {
        if (asDevId.Length == 0)
            return -1; // -1 : 파라메터가 비정상

        if (anBlkNo < 1)
            return -1;

        if (abytBlkData.Length == 0)
            return -1;

        try
        {
            string app_key;

            Context.Application.Lock();
            app_key = "key_dev_" + asDevId;

            if (anBlkNo == 1)
            {
                FKWebTransBlockData app_val_blk = (FKWebTransBlockData)Context.Application.Get(app_key);
                if (app_val_blk == null)
                {
                    // 이전에 해당 기대에 대한 블로크자료를 루적하기 위한 오브젝트가 창조되여 있지 않은 경우
                    //  새 오브젝트를 창조하고 Dictionary에 추가한다.
                    app_val_blk = new FKWebTransBlockData();
                    Context.Application.Add(app_key, app_val_blk);
                }
                else
                {
                    // 이전에 해당 기대에 대한 블로크자료를 루적하기 위한 오브젝트가 창조되여 있은 경우
                    //  그 오브젝트를 삭제하고 새 오브젝트를 창조한 다음 Dictionary에 추가한다.
                    Context.Application.Remove(app_key);
                    app_val_blk = new FKWebTransBlockData();
                    Context.Application.Add(app_key, app_val_blk);
                }

                // 첫 블로크자료를 블로크자료보관용 스트림에 추가한다.
                app_val_blk.LastBlockNo = 1;
                app_val_blk.TmLastModified = DateTime.Now;
                app_val_blk.MemStream = new MemoryStream();
                app_val_blk.MemStream.Write(abytBlkData, 0, abytBlkData.Length);
            }
            else
            {
                // 블로크번호가 1 이 아닌 경우
                FKWebTransBlockData app_val_blk = (FKWebTransBlockData)Context.Application.Get(app_key);
                if (app_val_blk == null)
                {
                    // 이미 기대에 대한 오브젝트가 창조되여 있지 않은 상태라면 
                    Context.Application.UnLock();
                    return -2;
                }
                if (app_val_blk.LastBlockNo != anBlkNo - 1)
                {
                    // 만일 마지막으로 받은 블로크번호가 새로 받을 블로크번호와 련속이 되지 않는다면
                    Context.Application.UnLock();
                    return -3;
                }

                // 새로 받은 블로크자료를 블로크자료보관용 스트림의 마지막에 추가한다.
                app_val_blk.LastBlockNo = anBlkNo;
                app_val_blk.TmLastModified = DateTime.Now;
                app_val_blk.MemStream.Seek(0, SeekOrigin.End);
                app_val_blk.MemStream.Write(abytBlkData, 0, abytBlkData.Length);
            }

            Context.Application.UnLock();
            return 0;
        }
        catch
        {
            Context.Application.UnLock();
            return -11;
        }
    }

    // 해당 기대에 대하여 메모리스트림에 루적된 자료를 얻어내고 그 메모리스트림을 삭제한다.
    protected int GetBlockDataAndRemove(string asDevId, out byte[] abytBlkData)
    {
        abytBlkData = new byte[0];

        if (asDevId.Length == 0)
            return -1;

        try
        {
            string app_key;

            Context.Application.Lock();
            app_key = "key_dev_" + asDevId;

            FKWebTransBlockData app_val_blk = (FKWebTransBlockData)Context.Application.Get(app_key);
            if (app_val_blk == null)
            {
                Context.Application.UnLock();
                return 0;
            }

            app_val_blk.MemStream.Seek(0, SeekOrigin.Begin);
            abytBlkData = new byte[app_val_blk.MemStream.Length];
            app_val_blk.MemStream.Read(abytBlkData, 0, abytBlkData.Length);
            Context.Application.Remove(app_key);

            Context.Application.UnLock();
            return 0;
        }
        catch
        {
            Context.Application.UnLock();
            return -11;
        }
    }

    protected void RemoveOldBlockStream()
    {
        DateTime dtCur = DateTime.Now;
        TimeSpan delta;
        try
        {
            Context.Application.Lock();

            List<string> listDevIdKey = new List<string>();
            FKWebTransBlockData app_val_blk;
            int k;
            int cnt = Context.Application.Count;
            for (k = 0; k < cnt; k++)
            {
                string sKey = Context.Application.GetKey(k);
                if (String.Compare(sKey, 0, "key_dev_", 0, 8, true) != 0)
                    continue;

                app_val_blk = (FKWebTransBlockData)Context.Application.Get(k);
                delta = dtCur - app_val_blk.TmLastModified;
                if (delta.Minutes > 30)
                    listDevIdKey.Add(sKey);
            }

            foreach (string key_dev in listDevIdKey)
                Context.Application.Remove(key_dev);

            Context.Application.UnLock();
        }
        catch
        {
            Context.Application.UnLock();
        }
    }

    protected void OnSendCmdResult(FKWebCmdTrans aCmdTrans, string asDevId, string asTransId, byte[] abytRequest)
    {
        const string csFuncName = "Page_Load - send_cmd_result";

        byte[] bytCmdResult = abytRequest;
        byte[] bytEmpty = new byte[0];
        string sResponse;
        string sTransId;
        string sReturnCode;

        aCmdTrans.PrintDebugMsg1(csFuncName, "1");

        sTransId = asTransId;

        SqlConnection sqlConn;
        string sDbConn = ConfigurationManager.ConnectionStrings["SqlConnFkWeb"].ConnectionString.ToString();
        sqlConn = new SqlConnection(sDbConn);
        try
        {
            if (sqlConn.State == ConnectionState.Closed)
                sqlConn.Open();
        }
        catch (Exception)
        {
            aCmdTrans.PrintDebugMsg1(csFuncName, "1.1");

            sqlConn.Close();
            sqlConn.Dispose();
            SendResponseToClient("ERROR_DB_ACCESS", sTransId, "", bytEmpty);
            return;
        }

        try
        {
            aCmdTrans.PrintDebugMsg1(csFuncName, "2 - trans_id:" + sTransId);

            // 해당 지령을 통신하는 기대에 대해 '기대재기동'지령이 발행된것이 있는가 조사하여
            //  있으면 기대에 응답으로서 '기대재기동'을 내려보낸다.
            string sTransIdTemp;
            if (aCmdTrans.CheckResetCmd(sqlConn, asDevId, out sTransIdTemp))
            {
                aCmdTrans.PrintDebugMsg1(csFuncName, "2.1");

                sqlConn.Close();
                sqlConn.Dispose();
                SendResponseToClient("RESET_FK", sTransId, "", bytEmpty);
                return;
            }
            // 해당 지령이 '취소'되였으면 그에 대해 응답한다.
            if (aCmdTrans.IsCancelledCmd(sqlConn, asDevId, sTransId))
            {
                aCmdTrans.PrintDebugMsg1(csFuncName, "2.2");
                sqlConn.Close();
                sqlConn.Dispose();
                SendResponseToClient("ERROR_CANCELED", sTransId, "", bytEmpty);
                return;
            }
            sqlConn.Close();
            sqlConn.Dispose();

            aCmdTrans.PrintDebugMsg1(csFuncName, "3");

            sReturnCode = Request.Headers["cmd_return_code"].ToString();

            // 지령처리결과자료를 자료기지에 보관한다.
            aCmdTrans.SetCmdResult(sTransId, asDevId, sReturnCode, bytCmdResult, out sResponse);

            aCmdTrans.PrintDebugMsg1(csFuncName, "4");

            // HTTP클라이언트에 응답을 보낸다.
            SendResponseToClient(sResponse, sTransId, "", bytEmpty);

            aCmdTrans.PrintDebugMsg1(csFuncName, "5");
        }
        catch (Exception ex)
        {
            sqlConn.Close();
            sqlConn.Dispose();
            aCmdTrans.PrintDebugMsg(csFuncName, "Except - 1 - " + ex.ToString());
            // exception이 발생하면 접속을 차단한다.                
            Response.Close();
            return;
        }
    }

    protected void OnRealtimeGLog(FKWebCmdTrans aCmdTrans, string asDevId, byte[] abytRequest)
    {
        const string csFuncName = "Page_Load - realtime_glog";

        string sRequest = "";
        string sResponse;
        byte[] bytRequest = abytRequest;
        byte[] bytLogImage = new byte[0];

        try
        {
            aCmdTrans.PrintDebugMsg1(csFuncName, "1------------------>");

            // 실시간로그자료가 올라올때 사용자ID, 확인방식, 출입방식, 출입시간이 body부분에 포함되여 올라온다.
            // 로그화상자료는 경우에 따라 존재할수도 있고 존재하지 않을수도 있다.
            if (aCmdTrans.DevModel == null)
            {
                FKWebCmdTrans.GetStringAnd1stBinaryFromBSCommBuffer(
                    bytRequest, out sRequest, out bytLogImage);
            }
            else
            {
                sRequest = System.Text.Encoding.UTF8.GetString(bytRequest);
            }
            if (sRequest.Length == 0)
            {
                aCmdTrans.PrintDebugMsg1(csFuncName, "1-- length=" + sRequest.Length);
                // 만일 실시간로그자료접수시에 올라온 문자렬의 길이가 0이면
                //  잘못된 요구가 올라온것으로 보고 접속을 차단한다.
                Response.Close();
                return;
            }

            aCmdTrans.PrintDebugMsg1(csFuncName, "2");

            string sUserId;
            string sVerifyMode;
            string sIOMode;
            string sIOTime;
            string sWorkCode;
            string sLogImg;
            string sFKBinDataLib;

            JObject jobjRequest = JObject.Parse(sRequest);
            aCmdTrans.PrintDebugMsg1(csFuncName, "2-1");
            // 이 필드는 올라온 실시간로그자료의 확인방식, 출입방식의 상수들을 해석하는데 리용된다. 
            sFKBinDataLib = jobjRequest["fk_bin_data_lib"].ToString();
            if (sFKBinDataLib.Length == 0)
            {
                aCmdTrans.PrintDebugMsg1(csFuncName, "2-- sFKBinDataLib.length=" + sFKBinDataLib.Length);
                Response.AddHeader("response_code", "ERROR_INVALID_LIB_NAME");
                Response.ContentType = "application/octet-stream";
                Response.AddHeader("Content-Length", Convert.ToString(0));
                Response.Close();
            }
            aCmdTrans.PrintDebugMsg1(csFuncName, "2-2");
            sUserId = jobjRequest["user_id"].ToString();
            sVerifyMode = jobjRequest["verify_mode"].ToString();
            sIOMode = jobjRequest["io_mode"].ToString();
            sIOTime = jobjRequest["io_time"].ToString();
            try
            {
                sWorkCode = jobjRequest["work_code"].ToString();
            }
            catch (Exception e)
            {
                sWorkCode = "0";
            }
            try
            {
                sLogImg = jobjRequest["log_image"].ToString();
            }
            catch (Exception e)
            {
                sLogImg = "";
            }
            aCmdTrans.PrintDebugMsg1(csFuncName, "2-3");
            aCmdTrans.PrintDebugMsg1(csFuncName, "2" + "user_id = " + sUserId + "  sIOTime = " + sIOTime);

            if (aCmdTrans.DevModel == null)
            {
                // 확인방식, 출입방식을 변환한다.
                if (sFKBinDataLib == "FKDataHS101" || sFKBinDataLib.ToUpper() == "FKDATAHS101")
                {
                    sIOMode = FKDataHS101.GLog.GetInOutModeString(Convert.ToInt32(sIOMode));
                    sVerifyMode = FKDataHS101.GLog.GetVerifyModeString(Convert.ToInt32(sVerifyMode));
                }
                else if (sFKBinDataLib == "FKDataHS102")
                {
                    sIOMode = FKDataHS102.GLog.GetInOutModeString(Convert.ToInt32(sIOMode));
                    sVerifyMode = FKDataHS102.GLog.GetVerifyModeString(Convert.ToInt32(sVerifyMode));
                }
                else if (sFKBinDataLib == "FKDataHS103")
                {
                    sIOMode = FKDataHS103.GLog.GetInOutModeString(Convert.ToInt32(sIOMode));
                    sVerifyMode = FKDataHS103.GLog.GetVerifyModeString(Convert.ToInt32(sVerifyMode));
                }
                else if (sFKBinDataLib == "FKDataHS105")
                {
                    sIOMode = FKDataHS105.GLog.GetInOutModeString(Convert.ToInt32(sIOMode));
                    sVerifyMode = FKDataHS105.GLog.GetVerifyModeString(Convert.ToInt32(sVerifyMode));
                }
                else if (sFKBinDataLib == "FKDataHS100")
                {
                    sIOMode = FKDataHS100.GLog.GetInOutModeString(Convert.ToInt32(sIOMode));
                    sVerifyMode = FKDataHS100.GLog.GetVerifyModeString(Convert.ToInt32(sVerifyMode));
                }

                else if (sFKBinDataLib == "FKDataHS200")
                {
                    sIOMode = FKDataHS200.GLog.GetInOutModeString(Convert.ToInt32(sIOMode));
                    sVerifyMode = FKDataHS200.GLog.GetVerifyModeString(Convert.ToInt32(sVerifyMode));
                }
            }
            else
            {
                if (sLogImg.Length > 0)
                    bytLogImage = Convert.FromBase64String(sLogImg);
            }

            aCmdTrans.PrintDebugMsg1(csFuncName, "3");

            sResponse = aCmdTrans.InsertRealtimeGLog(
                    asDevId,
                    sUserId,
                    sVerifyMode,
                    sIOMode,
                    sIOTime,
                    sWorkCode,
                    bytLogImage
                );

            Response.AddHeader("response_code", sResponse);
            Response.ContentType = "application/octet-stream";
            Response.AddHeader("Content-Length", Convert.ToString(0));
            Response.Flush();

            aCmdTrans.PrintDebugMsg1(csFuncName, "4");
        }
        catch (Exception ex)
        {
            aCmdTrans.PrintDebugMsg1(csFuncName, "Except - 1 - " + ex.ToString());
            // exception이 발생하면 접속을 차단한다.                
            Response.Close();
            return;
        }
    }

    /*protected void OnRealtimeSLog(FKWebCmdTrans aCmdTrans, string asDevId, byte[] abytRequest)
    {
        const string csFuncName = "Page_Load - realtime_slog";

        string sRequest = "";
        string sResponse;
        byte[] bytRequest = abytRequest;
        byte[] bytLogImage = new byte[0];

        try
        {
            aCmdTrans.PrintDebugMsg1(csFuncName, "1------------------>");

            FKWebCmdTrans.GetStringAnd1stBinaryFromBSCommBuffer(
                bytRequest, out sRequest, out bytLogImage);
            if (sRequest.Length == 0)
            {
                aCmdTrans.PrintDebugMsg1(csFuncName, "1-- length=" + sRequest.Length);
                Response.Close();
                return;
            }
            else
                aCmdTrans.PrintDebugMsg1(csFuncName, "jobj--->" + sRequest);

            aCmdTrans.PrintDebugMsg1(csFuncName, "2");

            string sUserId;
            string stoUserId;
            string skind;
            int sbackupNumber;
            int stobackupNumber;
            string soprt_time;
            string sFKBinDataLib;

            JObject jobjRequest = JObject.Parse(sRequest);
            aCmdTrans.PrintDebugMsg1(csFuncName, "2-1");

            sFKBinDataLib = jobjRequest["fk_bin_data_lib"].ToString();
            if (sFKBinDataLib.Length == 0)
            {
                aCmdTrans.PrintDebugMsg1(csFuncName, "2-- sFKBinDataLib.length=" + sFKBinDataLib.Length);
                Response.AddHeader("response_code", "ERROR_INVALID_LIB_NAME");
                Response.ContentType = "application/octet-stream";
                Response.AddHeader("Content-Length", Convert.ToString(0));
                Response.Close();
            }
            aCmdTrans.PrintDebugMsg1(csFuncName, "2-2");
            sUserId = jobjRequest["user_id"].ToString();
            stoUserId = jobjRequest["to_user_id"].ToString();
            skind = jobjRequest["Kind"].ToString();
            sbackupNumber = 0;
            stobackupNumber = 0;
            soprt_time = jobjRequest["time"].ToString();

            aCmdTrans.PrintDebugMsg1(csFuncName, "2-3");
            aCmdTrans.PrintDebugMsg1(csFuncName, "2" + "user_id = " + sUserId + "to_user_id = " + stoUserId + "skind = " + skind + "time = " + soprt_time);

            switch (skind)
            {
                case "32":
                    skind = "del";
                    break;
                default:
                    break;
            }

            aCmdTrans.PrintDebugMsg1(csFuncName, "3");

            sResponse = aCmdTrans.InsertRealtimeSLog(
                    asDevId,
                    sUserId,
                    stoUserId,
                    skind,
                    sbackupNumber,
                    stobackupNumber,
                    soprt_time
                );

            Response.AddHeader("response_code", sResponse);
            Response.ContentType = "application/octet-stream";
            Response.AddHeader("Content-Length", Convert.ToString(0));
            Response.Flush();

            aCmdTrans.PrintDebugMsg1(csFuncName, "4");
        }
        catch (Exception ex)
        {
            aCmdTrans.PrintDebugMsg1(csFuncName, "Except - 1 - " + ex.ToString());
            // exception이 발생하면 접속을 차단한다.                
            Response.Close();
            return;
        }
    }*/

    protected void OnRealtimeEnrollData(FKWebCmdTrans aCmdTrans, string asDevId, byte[] abytRequest)
    {
        const string csFuncName = "Page_Load - realtime_enroll_data";

        string sRequest;
        string sResponse;
        byte[] bytRequest = abytRequest;
        byte[] bytEmpty = new byte[0];

        try
        {
            aCmdTrans.PrintDebugMsg(csFuncName, "1");

            // 실시간등록자료가 올라올때 사용자ID는 body부분에 포함되여 올라온다.
            if (aCmdTrans.DevModel == null)
                sRequest = FKWebCmdTrans.GetStringFromBSCommBuffer(bytRequest);
            else
                sRequest = System.Text.Encoding.UTF8.GetString(bytRequest);
            if (sRequest.Length == 0)
            {
                // 만일 실시간등록자료접수시에 올라온 문자렬의 길이가 0이면
                //  잘못된 요구가 올라온것으로 보고 접속을 차단한다.
                Response.Close();
                return;
            }

            aCmdTrans.PrintDebugMsg(csFuncName, "2");

            JObject jobjRequest = JObject.Parse(sRequest);
            string sUserId = jobjRequest["user_id"].ToString();

            aCmdTrans.PrintDebugMsg(csFuncName, "3");

            sResponse = aCmdTrans.InsertRealtimeEnrollData(
                    asDevId,
                    sUserId,
                    bytRequest
                );

            Response.AddHeader("response_code", sResponse);
            Response.ContentType = "application/octet-stream";
            Response.AddHeader("Content-Length", Convert.ToString(0));
            Response.Flush();

            aCmdTrans.PrintDebugMsg(csFuncName, "4");
        }
        catch (Exception ex)
        {
            aCmdTrans.PrintDebugMsg(csFuncName, "Except - 1 - " + ex.ToString());
            // exception이 발생하면 접속을 차단한다.                
            Response.Close();
            return;
        }
    }

    protected void OnRealtimeDoorData(FKWebCmdTrans aCmdTrans, string asDevId, byte[] abytRequest)
    {
        const string csFuncName = "Page_Load - realtime_door_data";

        string sRequest;
        string sResponse;
        byte[] bytRequest = abytRequest;
        byte[] bytEmpty = new byte[0];

        try
        {
            aCmdTrans.PrintDebugMsg(csFuncName, "1");

            // 실시간등록자료가 올라올때 사용자ID는 body부분에 포함되여 올라온다.
            if (aCmdTrans.DevModel == null)
                sRequest = FKWebCmdTrans.GetStringFromBSCommBuffer(bytRequest);
            else
                sRequest = System.Text.Encoding.UTF8.GetString(bytRequest);
            if (sRequest.Length == 0)
            {
                // 만일 실시간등록자료접수시에 올라온 문자렬의 길이가 0이면
                //  잘못된 요구가 올라온것으로 보고 접속을 차단한다.
                Response.Close();
                return;
            }

            aCmdTrans.PrintDebugMsg(csFuncName, "2");

            JObject jobjRequest = JObject.Parse(sRequest);
            string sDoorStatus = jobjRequest["door_status"].ToString();

            aCmdTrans.PrintDebugMsg(csFuncName, "3");

            sResponse = aCmdTrans.InsertRealtimeDoorData(
                    asDevId,
                    sDoorStatus
                );

            Response.AddHeader("response_code", sResponse);
            Response.ContentType = "application/octet-stream";
            Response.AddHeader("Content-Length", Convert.ToString(0));
            Response.Flush();

            aCmdTrans.PrintDebugMsg(csFuncName, "4");
        }
        catch (Exception ex)
        {
            aCmdTrans.PrintDebugMsg(csFuncName, "Except - 1 - " + ex.ToString());
            // exception이 발생하면 접속을 차단한다.                
            Response.Close();
            return;
        }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        const string csFuncName = "Page_Load";
        string sDevId;
        string sTransId;
        string sRequestCode;
        string stokenid;
        string sDevModel;
        int lenContent;
        byte[] bytRequestBin;
        byte[] bytRequestTotal;
        byte[] bytEmpty = new byte[0];

        FKWebCmdTrans cmdTrans = new FKWebCmdTrans();

        //Debug.WriteLine("Loading the page");
        //cmdTrans.PrintDebugMsg(csFuncName, "1");

        //{ #### 이 부분은 자체검사를 위한 부분이다. 최종판본에서는 삭제해야 한다.
        //cmdTrans.PrintDebugMsg(csFuncName, "2 - HOST:" + Request.Headers["HOST"]);
        //cmdTrans.PrintDebugMsg(csFuncName, "2 - trans_id:" + Request.Headers["trans_id"]);
        //cmdTrans.PrintDebugMsg(csFuncName, "2 - dev_id:" + Request.Headers["dev_id"]);
        //cmdTrans.PrintDebugMsg(csFuncName, "2 - blk_id:" + Request.Headers["blk_id"]);

        //cmdTrans.Test();
        //cmdTrans.TestStoredProcedureBinData();
        //byte [] bytTest;
        //cmdTrans.CreateBSCommBufferFromString("aaa", out bytTest);
        //cmdTrans.TestNewtonsoftJsonLib();
        //cmdTrans.MakeSetTimeCmdParamBin("SET_TIME", ref bytTest);
        //} ####

        TRANSIDKEY = cmdTrans.getTransIdKey();

        stokenid = cmdTrans.getTokenId();
        if (stokenid != null)
        {
            if (!stokenid.Equals(Request.Headers["token_id"]))
                return;
        }

        //dev_model字段检查
        sDevModel = Request.Headers["dev_model"];
        if (FKWebTools.IsValidEngDigitString(sDevModel, 32))
        {
            cmdTrans.PrintDebugMsg(csFuncName, "DevModel : " + sDevModel);
            cmdTrans.DevModel = sDevModel;
        }

        // HTTP헤더에서 request_code 필드의 값을 얻는다.
        // 이 코드에는 현재의 요구가 무엇을 하려는것인가를 나타낸다.
        sRequestCode = Request.Headers["request_code"];

        if (!FKWebTools.IsValidEngDigitString(sRequestCode, 32))
        {
            cmdTrans.PrintDebugMsg(csFuncName, "error - Invalid request_code : " + sRequestCode);
            Response.Close();
            return;
        }
        // 일부 HTTP요구들에는 헤더에 trans_id필드가 존재하지 않을수도 있다.
        // 그러므로 그러한 경우에 대처하기 위하여 try/catch블로크를 사용한다.
        try
        {
            sTransId = Request.Headers[TRANSIDKEY];
            if (sTransId.Length > 0)
                cmdTrans.PrintDebugMsg(csFuncName, "**************** sRequestCode = " + sRequestCode + " dev_id=" + Request.Headers["dev_id"] + " trans_id=" + sTransId + " content_length=" + Request.Headers["Content-Length"]);

        }
        catch (Exception)
        {
            sTransId = "";
        }
        cmdTrans.PrintDebugMsg(csFuncName, "1 - request_code : " + sRequestCode + " ,trans_id : " + sTransId);

        // HTTP헤더에서 dev_id 필드의 값을 얻는다.
        // dev_id 필드의 값은 영수문자로서 최대 18문자이여야 한다. 
        // 만일 이 필드가 빈 문자렬이면 허튼 요구라고 보고 응답하지 않는다.
        sDevId = Request.Headers["dev_id"];
        if (!FKWebTools.IsValidEngDigitString(sDevId, 18))
        {
            cmdTrans.PrintDebugMsg(csFuncName, "error - Invalid dev_id : " + sDevId);
            Response.Close();
            return;
        }

        //cmdTrans.PrintDebugMsg(csFuncName, "2 - " + sDevId);
        //cmdTrans.PrintDebugMsg(csFuncName, "2 - " + sDevId+);

        // HTTP POST요구와 함께 올라오는 바이너리 자료를 수신한다.
        lenContent = GetRequestStreamBytes(out bytRequestBin);
        if (lenContent < 0)
        {
            cmdTrans.PrintDebugMsg1(csFuncName, "2.1" + lenContent);

            // 만일 HTTP 헤더의 Content-Length만한 바이트를 다 접수하지 못한 경우는 접속을 차단한다.
            Response.Close();
            return;
        }

        if (cmdTrans.DevModel == null)
        {
            // 기대는 HTTP요구에 덧붙여 보낼 자료가 클 때에는(5KB 이상)
            //  전체 자료를 블로크로 나누고 해당 request_code를 가진 요구를 여러번에 걸쳐 보낼수 있다.
            // 이때 첫시작블로크의 번호는 1, 마지막블로크의 번호는 0이다.
            // 서버측에서는 블로크번호가 1이상인 블로크가 올라오면 그 자료를 바퍼에 축적해나가다가 
            //  블로크번호 0인 블로크가 접수되면 축적된 자료를 가지고 실제의 처리를 진행한다. 
            // 블로크는 이전 블로크번호의 다음번호를 가지고 올라온다.
            int nBlkNo = Convert.ToInt32(Request.Headers["blk_no"]);
            int nBlkLen = Convert.ToInt32(Request.Headers["blk_len"]);
            int vRet;
            if (nBlkNo > 0)
            {
                cmdTrans.PrintDebugMsg1(csFuncName, "3.0 - blk_no=" + Convert.ToString(nBlkNo) + ", blk_len=" + Convert.ToString(nBlkLen));

                // 블로크번호가 1 이상인 경우는 해당 블로크에 대한 자료를
                //  Web App범위에서 관리되는 기대에 대한 메모리스트림에 추가한다.
                vRet = AddBlockData(sDevId, nBlkNo, bytRequestBin);
                if (vRet != 0)
                {
                    cmdTrans.PrintDebugMsg1(csFuncName, "3.0 - error - AddBlockData:" + Convert.ToString(vRet));
                    SendResponseToClient("ERROR_ADD_BLOCK_DATA", sTransId, "", bytEmpty);
                    return;
                }

                cmdTrans.PrintDebugMsg1(csFuncName, "3.1");

                SendResponseToClient("OK", sTransId, "", bytEmpty);
                return;
            }
            else if (nBlkNo < 0)
            {
                cmdTrans.PrintDebugMsg(csFuncName, "3.3 - blk_no=" + Convert.ToString(nBlkNo) + ", blk_len=" + Convert.ToString(nBlkLen));

                // 비정상적인 HTTP요구(블로크번호가 무효한 값)가 올라온 경우이다.
                SendResponseToClient("ERROR_INVLAID_BLOCK_NO", sTransId, "", bytEmpty);
                return;
            }
            else
            {
                cmdTrans.PrintDebugMsg(csFuncName, "3.4 - blk_no=" + Convert.ToString(nBlkNo) + ", blk_len=" + Convert.ToString(nBlkLen));

                // 기대측에서 결과자료를 보낼때 마지막 블로크를 보냈다면
                //  메모리스트림에 루적하였던 자료를 얻어내여 그 뒤에 최종으로 받은 블로크를 덧붙인다.
                GetBlockDataAndRemove(sDevId, out bytRequestTotal);
                FKWebTools.ConcateByteArray(ref bytRequestTotal, bytRequestBin);
            }
        }
        else
        {
            bytRequestTotal = new byte[bytRequestBin.Length];
            System.Array.Copy(bytRequestBin, bytRequestTotal, bytRequestBin.Length);
        }

        if (sRequestCode == REQ_CODE_RECV_CMD)
        {
            // 블로크자료를 접수하기 위하여 창조하였던 스트림오브젝트가 지내 이전에 만들어진것이면
            //  그것을 삭제한다. 이러한 상황은 기대가 블로크자료를 올려보내던 도중 정전과 같은 이상현상으로 죽어버린 이후로부터
            //  현재까지 아무런 요구도 보내지 않으면 발생한다.
            RemoveOldBlockStream();

            OnReceiveCmd(cmdTrans, sDevId, sTransId, bytRequestTotal);
        }
        else if (sRequestCode == REQ_CODE_SEND_CMD_RESULT)
        {
            OnSendCmdResult(cmdTrans, sDevId, sTransId, bytRequestTotal);
        }
        else if (sRequestCode == REQ_CODE_REALTIME_GLOG)
        {
            OnRealtimeGLog(cmdTrans, sDevId, bytRequestTotal);
        }
        else if (sRequestCode == REQ_CODE_REALTIME_ENROLL)
        {
            OnRealtimeEnrollData(cmdTrans, sDevId, bytRequestTotal);
        }
        else if (sRequestCode == REQ_CODE_REALTIME_DOOR)
        {
            OnRealtimeDoorData(cmdTrans, sDevId, bytRequestTotal);
        }
        /*else if (sRequestCode == REQ_CODE_REALTIME_SLOG)
        {
            OnRealtimeSLog(cmdTrans, sDevId, bytRequestTotal);
        }*/
        else
        {
            SendResponseToClient("ERROR_INVLAID_REQUEST_CODE", sTransId, "", bytEmpty);
            return;
        }
    }
}
