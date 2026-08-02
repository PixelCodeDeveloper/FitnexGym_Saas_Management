using System;
using System.Collections;
using System.Configuration;
using System.Data;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.HtmlControls;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.IO;
using FKWeb;
using System.Data.SqlClient;
using System.Net;

public partial class DeviceManage : System.Web.UI.Page
{
  string mDevId;
  string mDevModel;
  string mTransId;
  SqlConnection msqlConn;

  const int GETUSERPASSTIME = 0;
  const int GETTIMEZONE = 1;
  const int GETDEVICESETTING = 2;
  const int SETUSERPASSTIME = 3;
  const int SETTIMEZONE = 4;
  const int SETDEVICESETTING = 5;
  const int SETDOORSTATUS = 6;

  protected void Page_Load(object sender, EventArgs e)
  {
    mDevId = (string)Session["dev_id"];
    mDevModel = (string)Session["dev_model"];

    DevID.Text = mDevId;

    msqlConn = FKWebTools.GetDBPool();
  }
  protected void goback_Click(object sender, EventArgs e)
  {
    Response.Redirect("Default.aspx");
  }

  public void ShowMessage(String msgStr)
  {

    System.Text.StringBuilder sb = new System.Text.StringBuilder();

    sb.Append("<script type = 'text/javascript'>");

    sb.Append("window.onload=function(){");

    sb.Append("alert('");

    sb.Append(msgStr);

    sb.Append("')};");

    sb.Append("</script>");

    ClientScript.RegisterClientScriptBlock(this.GetType(), "alert", sb.ToString());

  }

  private void Enables(bool flag)
  {
    SetDeviceSettingBtn.Enabled = flag;
    GetDeviceSettingBtn.Enabled = flag;
    SetTimeZoneBtn.Enabled = flag;
    GetTimeZoneBtn.Enabled = flag;
    SetUserPassTimeBtn.Enabled = flag;
    GetUserPassTimeBtn.Enabled = flag;
    PanelDeviceSetting.Enabled = flag;
    PanelTimeZoneNo.Enabled = flag;
    PanelUserPassTime.Enabled = flag;
    Timer.Enabled = !flag;
  }

  protected void Timer_Watch(object sender, EventArgs e)
  {
    string sTransId = mTransIdTxt.Text;
    if (sTransId.Length == 0)
    {
      return;
    }
    string sSql = "select status from tbl_fkcmd_trans where trans_id='" + sTransId + "'";
    SqlCommand sqlCmd = new SqlCommand(sSql, msqlConn);
    SqlDataReader sqlReader = sqlCmd.ExecuteReader();
    try
    {
      if (sqlReader.HasRows)
      {
        if (sqlReader.Read())
        {

          if (sqlReader.GetString(0) == "RESULT" || sqlReader.GetString(0) == "CANCELLED")
          {
            StatusTxt.Text = sqlReader.GetString(0) + " : OK!";
            Enables(true);

            if ((int)Session["operation"] == GETUSERPASSTIME)
            {
              sqlReader.Close();
              DisplayUserPassTime();
              return;
            }

            if ((int)Session["operation"] == GETTIMEZONE)
            {
              sqlReader.Close();
              DisplayTimeZone();
              return;
            }

            if ((int)Session["operation"] == GETDEVICESETTING)
            {
              sqlReader.Close();
              DisplayDeviceSetting();
              return;
            }
          }
          else
            StatusTxt.Text = "       Device Status: " + sqlReader.GetString(0) + "&nbsp;&nbsp;&nbsp; Current Time :" + DateTime.Now.ToString("HH:mm:ss tt");
        }
        sqlReader.Close();
      }

    }
    catch (Exception ex)
    {
      StatusTxt.Text = StatusTxt.Text + ex.ToString();
      sqlReader.Close();
    }
  }

  private string GetJsonString()
  {
    string sTransId = mTransIdTxt.Text;
    FKWebCmdTrans cmdTrans = new FKWebCmdTrans();

    string sCmdCode = "";
    string sReturn_code = "";
    if (sTransId.Length == 0)
      return null;
    string sSql = "select trans_id, cmd_code, return_code from tbl_fkcmd_trans where trans_id='" + sTransId + "' AND status='RESULT'";
    SqlCommand sqlCmd = new SqlCommand(sSql, msqlConn);
    SqlDataReader sqlReader = sqlCmd.ExecuteReader();

    sTransId = "";
    if (sqlReader.HasRows)
    {
      if (sqlReader.Read())
      {
        sTransId = sqlReader.GetString(0);
        sCmdCode = sqlReader.GetString(1);
        sReturn_code = sqlReader.GetString(2);
        if (!"OK".Equals(sReturn_code))
        {
          StatusTxt.Text = StatusTxt.Text + sReturn_code;
          return null;
        }
      }
    }
    sqlReader.Close();

    if (sTransId.Length == 0)
      return null;

    sSql = "select @cmd_result=cmd_result from tbl_fkcmd_trans_cmd_result where trans_id='" + sTransId + "'";
    sqlCmd = new SqlCommand(sSql, msqlConn);
    SqlParameter sqlParamCmdParamBin = new SqlParameter("@cmd_result", SqlDbType.VarBinary);
    sqlParamCmdParamBin.Direction = ParameterDirection.Output;
    sqlParamCmdParamBin.Size = -1;
    sqlCmd.Parameters.Add(sqlParamCmdParamBin);

    sqlCmd.ExecuteNonQuery();

    byte[] bytCmdResult = (byte[])sqlParamCmdParamBin.Value;

    byte[] bytResultBin = new byte[0];
    string sResultText;


    cmdTrans.GetStringAndBinaryFromBSCommBuffer(bytCmdResult, out sResultText, out bytResultBin);

    if (sResultText.Length == 0)
      return null;
    return sResultText;
  }

  private void DisplayUserPassTime()
  {
    JObject vResultJson;

    try
    {
      string json_str = GetJsonString();
      if (json_str == null) return;
      vResultJson = JObject.Parse(json_str);

      UserIDTxt.Text = vResultJson["user_id"].ToString();
      ValideDateStartTxt.Text = vResultJson["Valide_Date_start"].ToString();
      ValideDateEndTxt.Text = vResultJson["Valide_Date_end"].ToString();
      JArray Week_TimeZone = JArray.Parse(vResultJson["Week_TimeZone_No"].ToString());
      SunTxt.Text = Week_TimeZone[0].ToString();
      MonTxt.Text = Week_TimeZone[1].ToString();
      TueTxt.Text = Week_TimeZone[2].ToString();
      WebTxt.Text = Week_TimeZone[3].ToString();
      ThuTxt.Text = Week_TimeZone[4].ToString();
      FriTxt.Text = Week_TimeZone[5].ToString();
      SatTxt.Text = Week_TimeZone[6].ToString();
    }
    catch (Exception e)
    {
      StatusTxt.Text = StatusTxt.Text + e.ToString();
    }
  }

  private void DisplayTimeZone()
  {
    JObject vResultJson;
    JObject vT;

    try
    {
      string json_str = GetJsonString();
      if (json_str == null) return;
      vResultJson = JObject.Parse(json_str);

      TimeZoneNoTxt.Text = vResultJson["TimeZone_No"].ToString();
      vT = JObject.Parse(vResultJson["T1"].ToString());
      T1StartTxt.Text = vT["start"].ToString();
      T1EndTxt.Text = vT["end"].ToString();
      vT = JObject.Parse(vResultJson["T2"].ToString());
      T2StartTxt.Text = vT["start"].ToString();
      T2EndTxt.Text = vT["end"].ToString();
      vT = JObject.Parse(vResultJson["T3"].ToString());
      T3StartTxt.Text = vT["start"].ToString();
      T3EndTxt.Text = vT["end"].ToString();
      vT = JObject.Parse(vResultJson["T4"].ToString());
      T4StartTxt.Text = vT["start"].ToString();
      T4EndTxt.Text = vT["end"].ToString();
      vT = JObject.Parse(vResultJson["T5"].ToString());
      T5StartTxt.Text = vT["start"].ToString();
      T5EndTxt.Text = vT["end"].ToString();
      vT = JObject.Parse(vResultJson["T6"].ToString());
      T6StartTxt.Text = vT["start"].ToString();
      T6EndTxt.Text = vT["end"].ToString();
    }
    catch (Exception e)
    {
      StatusTxt.Text = StatusTxt.Text + e.ToString();
    }
  }

  private void DisplayDeviceSetting()
  {
    JObject vResultJson;
    try
    {
      string json_str = GetJsonString();
      if (json_str == null) return;
      vResultJson = JObject.Parse(json_str);

      if (vResultJson.Property("OpenDoor_Delay") != null)
        OpenDoorDelayTxt.Text = vResultJson["OpenDoor_Delay"].ToString();
      if (vResultJson.Property("DoorMagnetic_Delay") != null)
        DoorMagneticDelayTxt.Text = vResultJson["DoorMagnetic_Delay"].ToString();
      if (vResultJson.Property("Alarm_Delay") != null)
        AlarmDelayTxt.Text = vResultJson["Alarm_Delay"].ToString();
      if (vResultJson.Property("Sleep_Time") != null)
        SleepTimeTxt.Text = vResultJson["Sleep_Time"].ToString();
      if (vResultJson.Property("Screensavers_Time") != null)
        ScreensaversTimeTxt.Text = vResultJson["Screensavers_Time"].ToString();
      if (vResultJson.Property("Reverify_Time") != null)
        ReverifyTimeTxt.Text = vResultJson["Reverify_Time"].ToString();
      if (vResultJson.Property("DoorMagnetic_Type") != null)
        DoorMagneticTypeSelect.Text = vResultJson["DoorMagnetic_Type"].ToString();
      if (vResultJson.Property("Anti-back") != null)
        AntibackSelect.Text = vResultJson["Anti-back"].ToString();
      if (vResultJson.Property("Use_Alarm") != null)
        UseAlarmSelect.Text = vResultJson["Use_Alarm"].ToString();
      if (vResultJson.Property("Wiegand_Type") != null)
        WiegandTypeSelect.Text = vResultJson["Wiegand_Type"].ToString();
      if (vResultJson.Property("Glog_Warning") != null)
        GlogWarningTxt.Text = vResultJson["Glog_Warning"].ToString();
      if (vResultJson.Property("Volume") != null)
        VolumeTxt.Text = vResultJson["Volume"].ToString();
    }
    catch (Exception e)
    {
      StatusTxt.Text = StatusTxt.Text + e.ToString();
    }
  }

  protected void SetUserPassTimeBtn_Click(object sender, EventArgs e)
  {
    try
    {
      JObject vResultJson = new JObject();
      JArray vResultJarr = new JArray();
      FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
      string vuser_id = UserIDTxt.Text.Trim();
      string vValide_Date_start = ValideDateStartTxt.Text.Trim();
      string vValide_Date_end = ValideDateEndTxt.Text.Trim();
      string vTimeZoneNo = "";

      if (string.IsNullOrEmpty(vuser_id) || string.IsNullOrEmpty(vValide_Date_start) || string.IsNullOrEmpty(vValide_Date_end)) return;

      vResultJson.Add("user_id", vuser_id);
      vResultJson.Add("Valide_Date_start", vValide_Date_start);
      vResultJson.Add("Valide_Date_end", vValide_Date_end);

      vTimeZoneNo = SunTxt.Text.Trim();
      if (string.IsNullOrEmpty(vTimeZoneNo)) vTimeZoneNo = "1";
      vResultJarr.Add(vTimeZoneNo);

      vTimeZoneNo = MonTxt.Text.Trim();
      if (string.IsNullOrEmpty(vTimeZoneNo)) vTimeZoneNo = "1";
      vResultJarr.Add(vTimeZoneNo);

      vTimeZoneNo = TueTxt.Text.Trim();
      if (string.IsNullOrEmpty(vTimeZoneNo)) vTimeZoneNo = "1";
      vResultJarr.Add(vTimeZoneNo);

      vTimeZoneNo = WebTxt.Text.Trim();
      if (string.IsNullOrEmpty(vTimeZoneNo)) vTimeZoneNo = "1";
      vResultJarr.Add(vTimeZoneNo);

      vTimeZoneNo = ThuTxt.Text.Trim();
      if (string.IsNullOrEmpty(vTimeZoneNo)) vTimeZoneNo = "1";
      vResultJarr.Add(vTimeZoneNo);

      vTimeZoneNo = FriTxt.Text.Trim();
      if (string.IsNullOrEmpty(vTimeZoneNo)) vTimeZoneNo = "1";
      vResultJarr.Add(vTimeZoneNo);

      vTimeZoneNo = SatTxt.Text.Trim();
      if (string.IsNullOrEmpty(vTimeZoneNo)) vTimeZoneNo = "1";
      vResultJarr.Add(vTimeZoneNo);

      vResultJson.Add("Week_TimeZone_No", vResultJarr);
      string sFinal = vResultJson.ToString(Formatting.None);
      byte[] strParam = new byte[0];
      if (string.IsNullOrEmpty(mDevModel))
        cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);
      else
        strParam = System.Text.Encoding.UTF8.GetBytes(sFinal);
      mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "SET_USER_PASSTIME", mDevId, strParam);
      Session["operation"] = SETUSERPASSTIME;
      Enables(false);
    }
    catch (Exception ex)
    {
      StatusTxt.Text = ex.ToString();
      //StatusTxt.Text = "Error: Set user passtime fail!";
    }
  }

  protected void GetUserPassTimeBtn_Click(object sender, EventArgs e)
  {
    byte[] mByteParam = new byte[0];
    string mStrParam;
    string mUserId;
    try
    {
      Enables(false);
      JObject vResultJson = new JObject();
      FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
      mUserId = UserIDTxt.Text;

      vResultJson.Add("user_id", mUserId);
      mStrParam = vResultJson.ToString(Formatting.None);
      if (string.IsNullOrEmpty(mDevModel))
        cmdTrans.CreateBSCommBufferFromString(mStrParam, out mByteParam);
      else
        mByteParam = System.Text.Encoding.UTF8.GetBytes(mStrParam);
      mTransId = FKWebTools.MakeCmd(msqlConn, "GET_USER_PASSTIME", mDevId, mByteParam);
      mTransIdTxt.Text = mTransId;
      Session["operation"] = GETUSERPASSTIME;

      Enables(false);
    }
    catch (Exception ex)
    {
      StatusTxt.Text = ex.ToString();
    }
  }
  protected void SetTimeZoneBtn_Click(object sender, EventArgs e)
  {
    try
    {
      JObject vResultJson = new JObject();
      JObject vT;
      FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
      string start = "", end = "";
      vResultJson.Add("TimeZone_No", TimeZoneNoTxt.Text.Trim());

      vT = new JObject();
      start = T1StartTxt.Text.Trim();
      end = T1EndTxt.Text.Trim();
      if (string.IsNullOrEmpty(start)) start = "0000";
      if (string.IsNullOrEmpty(end)) end = "0000";
      vT.Add("start", start);
      vT.Add("end", end);
      vResultJson.Add("T1", vT);

      vT = new JObject();
      start = T2StartTxt.Text.Trim();
      end = T2EndTxt.Text.Trim();
      if (string.IsNullOrEmpty(start)) start = "0000";
      if (string.IsNullOrEmpty(end)) end = "0000";
      vT.Add("start", start);
      vT.Add("end", end);
      vResultJson.Add("T2", vT);

      vT = new JObject();
      start = T3StartTxt.Text.Trim();
      end = T3EndTxt.Text.Trim();
      if (string.IsNullOrEmpty(start)) start = "0000";
      if (string.IsNullOrEmpty(end)) end = "0000";
      vT.Add("start", start);
      vT.Add("end", end);
      vResultJson.Add("T3", vT);

      vT = new JObject();
      start = T4StartTxt.Text.Trim();
      end = T4EndTxt.Text.Trim();
      if (string.IsNullOrEmpty(start)) start = "0000";
      if (string.IsNullOrEmpty(end)) end = "0000";
      vT.Add("start", start);
      vT.Add("end", end);
      vResultJson.Add("T4", vT);

      vT = new JObject();
      start = T5StartTxt.Text.Trim();
      end = T5EndTxt.Text.Trim();
      if (string.IsNullOrEmpty(start)) start = "0000";
      if (string.IsNullOrEmpty(end)) end = "0000";
      vT.Add("start", start);
      vT.Add("end", end);
      vResultJson.Add("T5", vT);

      vT = new JObject();
      start = T6StartTxt.Text.Trim();
      end = T6EndTxt.Text.Trim();
      if (string.IsNullOrEmpty(start)) start = "0000";
      if (string.IsNullOrEmpty(end)) end = "0000";
      vT.Add("start", start);
      vT.Add("end", end);
      vResultJson.Add("T6", vT);

      string sFinal = vResultJson.ToString(Formatting.None);
      byte[] strParam = new byte[0];
      if (string.IsNullOrEmpty(mDevModel))
        cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);
      else
        strParam = System.Text.Encoding.UTF8.GetBytes(sFinal);
      mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "SET_TIMEZONE", mDevId, strParam);
      Session["operation"] = SETTIMEZONE;
      Enables(false);
    }
    catch (Exception ex)
    {
      StatusTxt.Text = ex.ToString();
      //StatusTxt.Text = "Error: Set TimeZone fail!";
    }
  }
  protected void GetTimeZoneBtn_Click(object sender, EventArgs e)
  {
    byte[] mByteParam = new byte[0];
    string mStrParam;
    string TimeZone_No;
    try
    {
      Enables(false);
      JObject vResultJson = new JObject();
      FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
      TimeZone_No = TimeZoneNoTxt.Text;

      vResultJson.Add("TimeZone_No", TimeZone_No);
      mStrParam = vResultJson.ToString(Formatting.None);
      if (string.IsNullOrEmpty(mDevModel))
        cmdTrans.CreateBSCommBufferFromString(mStrParam, out mByteParam);
      else
        mByteParam = System.Text.Encoding.UTF8.GetBytes(mStrParam);
      mTransId = FKWebTools.MakeCmd(msqlConn, "GET_TIMEZONE", mDevId, mByteParam);
      mTransIdTxt.Text = mTransId;
      Session["operation"] = GETTIMEZONE;

      Enables(false);
    }
    catch (Exception ex)
    {
      StatusTxt.Text = ex.ToString();
    }
  }
  protected void SetDeviceSettingBtn_Click(object sender, EventArgs e)
  {
    try
    {
      JObject vResultJson = new JObject();
      FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
      string vdata = "";
      vdata = OpenDoorDelayTxt.Text.Trim();
      if (!string.IsNullOrEmpty(vdata))
        vResultJson.Add("OpenDoor_Delay", vdata);

      vdata = DoorMagneticTypeSelect.Text.Trim();
      if (!string.IsNullOrEmpty(vdata))
        vResultJson.Add("DoorMagnetic_Type", vdata);

      vdata = DoorMagneticDelayTxt.Text.Trim();
      if (!string.IsNullOrEmpty(vdata))
        vResultJson.Add("DoorMagnetic_Delay", vdata);

      vdata = AntibackSelect.Text.Trim();
      if (!string.IsNullOrEmpty(vdata))
        vResultJson.Add("Anti-back", vdata);

      vdata = AlarmDelayTxt.Text.Trim();
      if (!string.IsNullOrEmpty(vdata))
        vResultJson.Add("Alarm_Delay", vdata);

      vdata = UseAlarmSelect.Text.Trim();
      if (!string.IsNullOrEmpty(vdata))
        vResultJson.Add("Use_Alarm", vdata);

      vdata = WiegandTypeSelect.Text.Trim();
      if (!string.IsNullOrEmpty(vdata))
        vResultJson.Add("Wiegand_Type", vdata);

      vdata = SleepTimeTxt.Text.Trim();
      if (!string.IsNullOrEmpty(vdata))
        vResultJson.Add("Sleep_Time", vdata);

      vdata = ScreensaversTimeTxt.Text.Trim();
      if (!string.IsNullOrEmpty(vdata))
        vResultJson.Add("Screensavers_Time", vdata);

      vdata = ReverifyTimeTxt.Text.Trim();
      if (!string.IsNullOrEmpty(vdata))
        vResultJson.Add("Reverify_Time", vdata);

      vdata = GlogWarningTxt.Text.Trim();
      if (!string.IsNullOrEmpty(vdata))
        vResultJson.Add("Glog_Warning", vdata);

      vdata = VolumeTxt.Text.Trim();
      if (!string.IsNullOrEmpty(vdata))
        vResultJson.Add("Volume", vdata);

      string sFinal = vResultJson.ToString(Formatting.None);
      byte[] strParam = new byte[0];
      if (string.IsNullOrEmpty(mDevModel))
        cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);
      else
        strParam = System.Text.Encoding.UTF8.GetBytes(sFinal);
      mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "SET_DEVICE_SETTING", mDevId, strParam);
      Session["operation"] = SETDEVICESETTING;
      Enables(false);
    }
    catch (Exception ex)
    {
      StatusTxt.Text = ex.ToString();
      //StatusTxt.Text = "Error: Set device Setting fail!";
    }
  }
  protected void GetDeviceSettingBtn_Click(object sender, EventArgs e)
  {
    byte[] mByteParam = new byte[0];
    string mStrParam;
    try
    {
      Enables(false);
      JObject vResultJson = new JObject();
      FKWebCmdTrans cmdTrans = new FKWebCmdTrans();

      vResultJson.Add("dev_id", mDevId);
      mStrParam = vResultJson.ToString(Formatting.None);
      if (string.IsNullOrEmpty(mDevModel))
        cmdTrans.CreateBSCommBufferFromString(mStrParam, out mByteParam);
      else
        mByteParam = System.Text.Encoding.UTF8.GetBytes(mStrParam);
      mTransId = FKWebTools.MakeCmd(msqlConn, "GET_DEVICE_SETTING", mDevId, mByteParam);
      mTransIdTxt.Text = mTransId;
      Session["operation"] = GETDEVICESETTING;

      Enables(false);
    }
    catch (Exception ex)
    {
      StatusTxt.Text = ex.ToString();
    }
  }
  protected void SetDoorStatusBtn_Click(object sender, EventArgs e)
  {
    try
    {
      JObject vResultJson = new JObject();
      FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
      vResultJson.Add("door_status", SetDoorStatusSelect.Text);

      string sFinal = vResultJson.ToString(Formatting.None);
      byte[] strParam = new byte[0];
      if (string.IsNullOrEmpty(mDevModel))
        cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);
      else
        strParam = System.Text.Encoding.UTF8.GetBytes(sFinal);
      mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "SET_DOOR_STATUS", mDevId, strParam);
      Session["operation"] = SETDOORSTATUS;
      Enables(false);

      Enables(false);
    }
    catch (Exception ex)
    {
      StatusTxt.Text = ex.ToString();
    }
  }
}
