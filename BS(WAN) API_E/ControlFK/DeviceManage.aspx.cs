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
  SqlConnection msqlConn;

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
  protected void SetTimeBtn_Click(object sender, EventArgs e)
  {
    try
    {
      DateTime now = DateTime.Now;
      string sNowTxt = FKWebTools.GetFKTimeString14(now);
      JObject vResultJson = new JObject();
      FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
      vResultJson.Add("time", sNowTxt);
      string sFinal = vResultJson.ToString(Formatting.None);
      byte[] strParam = new byte[0];
      if (string.IsNullOrEmpty(mDevModel))
        cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);
      else
        strParam = System.Text.Encoding.UTF8.GetBytes(sFinal);
      mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "SET_TIME", mDevId, strParam);
      Enables(false);
    }
    catch
    {
      StatusTxt.Text = "Error: Set time fail!";
    }
  }
  protected void ResetBtn_Click(object sender, EventArgs e)
  {
    try
    {
      mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "RESET_FK", mDevId, null);

      Enables(false);
    }
    catch
    {
      StatusTxt.Text = "Error: Reboot device fail!";
    }
  }
  protected void ClearBtn_Click(object sender, EventArgs e)
  {
    try
    {
      mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "CLEAR_ENROLL_DATA", mDevId, null);
      StatusTxt.Text = "Success : All of enroll data has been deleted!";
      Enables(false);
    }
    catch (Exception ex)
    {
      StatusTxt.Text = "Error: All of enroll data delete operation failed!";
    }
  }
  protected void ClearLogBtn_Click(object sender, EventArgs e)
  {
    try
    {
      mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "CLEAR_LOG_DATA", mDevId, null);
      StatusTxt.Text = "Success : All of log data has been deleted!";
      Enables(false);
    }
    catch (Exception ex)
    {
      StatusTxt.Text = "Error: All of log data delete operation failed!";
    }
  }
  protected void DevNameChangeBtn_Click(object sender, EventArgs e)
  {
    string mDevNameTxt = mDeviceName.Text;
    if (mDevNameTxt.Length == 0)
    {
      StatusTxt.Text = ("Input the device name!");
      return;
    }
    try
    {
      JObject vResultJson = new JObject();
      FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
      vResultJson.Add("fk_name", mDevNameTxt);
      string sFinal = vResultJson.ToString(Formatting.None);
      byte[] strParam = new byte[0];
      if (string.IsNullOrEmpty(mDevModel))
        cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);
      else
        strParam = System.Text.Encoding.UTF8.GetBytes(sFinal);
      mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "SET_FK_NAME", mDevId, strParam);
      StatusTxt.Text = "Success : Device name has been changed!";
      Enables(false);
    }
    catch
    {
      StatusTxt.Text = "Error : Device name has not been changed!";
    }
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
  protected void ServerChangeBtn_Click(object sender, EventArgs e)
  {
    string mServerIpTxt = mServerIP.Text;
    string mPortTxt = mServerPort.Text;
    int mPort;
    if (mServerIpTxt.Length == 0)
    {
      StatusTxt.Text = ("Input the server ip address!");
      return;
    }
    try
    {
      IPAddress ipAddr = IPAddress.Parse(mServerIpTxt);
    }
    catch
    {
      StatusTxt.Text = ("Invaild Ip address! Please Input the server ip address!");
      mServerIP.Text = "";
      return;
    }
    if (mPortTxt.Length == 0)
    {
      StatusTxt.Text = ("Input the server Port address!");
      return;
    }

    try
    {
      mPort = Convert.ToInt32(mPortTxt);
    }
    catch
    {
      StatusTxt.Text = ("Invaild port address! Please Input the server port address!");
      mServerPort.Text = "";
      return;
    }

    try
    {
      JObject vResultJson = new JObject();
      FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
      vResultJson.Add("ip_address", mServerIpTxt);
      vResultJson.Add("port", mPortTxt);
      string sFinal = vResultJson.ToString(Formatting.None);
      byte[] strParam = new byte[0];
      if (string.IsNullOrEmpty(mDevModel))
        cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);
      else
        strParam = System.Text.Encoding.UTF8.GetBytes(sFinal);
      mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "SET_WEB_SERVER_INFO", mDevId, strParam);
      StatusTxt.Text = "Success : Device's server info has been changed!,so that device is no longer in this server!";
      Enables(false);
    }
    catch
    {
      StatusTxt.Text = "Error : Device's server info has not been changed!";
    }

  }



  private string GetFirmwareFileName()
  {
    string sSql = "select device_info from tbl_fkdevice_status where device_id ='" + mDevId + "'";
    SqlCommand sqlCmd = new SqlCommand(sSql, msqlConn);
    SqlDataReader sqlReader = sqlCmd.ExecuteReader();
    string JsonStr = "";
    if (sqlReader.HasRows)
    {
      if (sqlReader.Read())
      {
        JsonStr = sqlReader.GetString(0);
        JObject jobjTest = JObject.Parse(JsonStr);
        JsonStr = jobjTest["firmware_filename"].ToString();
      }
    }
    sqlReader.Close();
    return JsonStr;
  }
  protected void UpdateBtn_Click(object sender, EventArgs e)
  {
    try
    {
      string default_filename = GetFirmwareFileName();
      string FirmwareBinDir = Path.GetDirectoryName(ConfigurationManager.AppSettings["FirmwareBinDir"]);
      byte[] bytCmdParamFirmwareBin = new byte[0];
      byte[] bytCmdParam = new byte[0];
      if (default_filename.Length == 0)
      {
        StatusTxt.Text = ("Couldn't get file name!");
        return;
      }
      Firmware.Text = default_filename;
      mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "UPDATE_FIRMWARE", mDevId, null);
      StatusTxt.Text = mTransIdTxt.Text;
      Enables(false);
    }
    catch (Exception ex)
    {
      StatusTxt.Text = ex.ToString();
    }

  }

  private void Enables(bool flag)
  {
    SetTimeBtn.Enabled = flag;
    ResetBtn.Enabled = flag;
    ClearBtn.Enabled = flag;
    ClearLogBtn.Enabled = flag;
    DevNameChangeBtn.Enabled = flag;
    ServerChangeBtn.Enabled = flag;
    UpdateBtn.Enabled = flag;
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
}
