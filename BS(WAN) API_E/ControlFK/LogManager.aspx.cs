using System;
using System.Collections.Generic;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Data.SqlClient;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.IO;
using FKWeb;
using System.Data;
using System.Configuration;

public partial class LogManager : System.Web.UI.Page
{
    SqlConnection msqlConn;
    string mDevId;
    int nCount = 0;
    const int GET_LOG_DATA = 0;
    const int GET_LOG_IMAGE = 1;
    const int GET_SLOG_DATA = 2;

    protected void Page_Load(object sender, EventArgs e)
    {
        try
        {
            mDevId = (string)Session["dev_id"];
            DevID.Text = mDevId;

            //  msDbConn = ConfigurationManager.ConnectionStrings["SqlConnFkWeb"].ConnectionString.ToString();

            //  msqlConn = new SqlConnection(msDbConn);

            msqlConn = FKWebTools.GetDBPool();


            gvLog.AllowPaging = true;
            gvLog.PageSize = 20;

            ViewState["SortExpression"] = "update_time ASC";

        }
        catch (Exception ex)
        {
            msqlConn.Close();
        }

    }

    private void BindGridView()
    {
        try
        {

            string mTransid = mTransIdTxt.Text;

            string strSelectCmd = "SELECT COUNT(*) FROM tbl_fkcmd_trans_cmd_result_log_data where trans_id = '" + mTransid + "'";
            SqlCommand sqlCmd = new SqlCommand(strSelectCmd, msqlConn);
            SqlDataReader sqlReader = sqlCmd.ExecuteReader();
            if (sqlReader.HasRows)
            {
                if (sqlReader.Read())
                    nCount = sqlReader.GetInt32(0);
            }
            sqlReader.Close();
            sqlCmd.Dispose();

            {
                DataSet dsLog = new DataSet();


                strSelectCmd = "SELECT * FROM tbl_fkcmd_trans_cmd_result_log_data where trans_id = '" + mTransid + "'";
                SqlDataAdapter da = new SqlDataAdapter(strSelectCmd, msqlConn);
                // conn.Open();
                da.Fill(dsLog, "tbl_fkcmd_trans_cmd_result_log_data");

                DataView dvLog = dsLog.Tables["tbl_fkcmd_trans_cmd_result_log_data"].DefaultView;

                gvLog.DataSource = dvLog;
                gvLog.DataBind();
                svLog.Visible = false;
                gvLog.Visible = true;
                StatusTxt.Text = "Total Count : " + Convert.ToString(nCount) + "&nbsp;&nbsp;&nbsp; Current Time :" + DateTime.Now.ToString("HH:mm:ss tt");
            }
        }
        catch (Exception ex)
        {
            StatusTxt.Text = ex.ToString();
        }

    }

    private void SBindGridView()
    {
        try
        {

            string mTransid = mTransIdTxt.Text;

            string strSelectCmd = "SELECT COUNT(*) FROM tbl_fkcmd_trans_cmd_result_slog_data where trans_id = '" + mTransid + "'";
            SqlCommand sqlCmd = new SqlCommand(strSelectCmd, msqlConn);
            SqlDataReader sqlReader = sqlCmd.ExecuteReader();
            if (sqlReader.HasRows)
            {
                if (sqlReader.Read())
                    nCount = sqlReader.GetInt32(0);
            }
            sqlReader.Close();
            sqlCmd.Dispose();

            {
                DataSet dsLog = new DataSet();


                strSelectCmd = "SELECT * FROM tbl_fkcmd_trans_cmd_result_slog_data where trans_id = '" + mTransid + "'";
                SqlDataAdapter da = new SqlDataAdapter(strSelectCmd, msqlConn);
                // conn.Open();
                da.Fill(dsLog, "tbl_fkcmd_trans_cmd_result_slog_data");

                DataView dvLog = dsLog.Tables["tbl_fkcmd_trans_cmd_result_slog_data"].DefaultView;

                svLog.DataSource = dvLog;
                svLog.DataBind();
                gvLog.Visible = false;
                svLog.Visible = true;
                StatusTxt.Text = "Total Count : " + Convert.ToString(nCount) + "&nbsp;&nbsp;&nbsp; Current Time :" + DateTime.Now.ToString("HH:mm:ss tt");
            }
        }
        catch (Exception ex)
        {
            StatusTxt.Text = ex.ToString();
        }

    }

    protected void gvLog_PageIndexChanging(object sender, GridViewPageEventArgs e)
    {
        // Set the index of the new display page.  
        gvLog.PageIndex = e.NewPageIndex;


        // Rebind the GridView control to  
        // show data in the new page. 
        if ((int)Session["operation"] == GET_LOG_DATA)
            BindGridView();
        else if ((int)Session["operation"] == GET_SLOG_DATA)
            SBindGridView();
    }

    protected void goback_Click(object sender, EventArgs e)
    {
        Response.Redirect("Default.aspx");
    }
    protected void GetLogBtn_Click(object sender, EventArgs e)
    {

        string sBeginDate = BeginDate.Text;
        string sEndDate = EndDate.Text;
        JObject vResultJson = new JObject();
        FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
        DateTime dtBegin, dtEnd;
        if (sBeginDate.Length > 0)
        {
            try
            {
                dtBegin = Convert.ToDateTime(sBeginDate);
                sBeginDate = FKWebTools.GetFKTimeString14(dtBegin);
                vResultJson.Add("begin_time", sBeginDate);

            }
            catch
            {

                BeginDate.Text = "";
            }
        }

        if (sEndDate.Length > 0)
        {
            try
            {
                dtEnd = Convert.ToDateTime(sEndDate);
                sEndDate = FKWebTools.GetFKTimeString14(dtEnd);
                vResultJson.Add("end_time", sEndDate);

            }
            catch
            {

                EndDate.Text = "";
            }
        }

        try
        {
            string sFinal = vResultJson.ToString(Formatting.None);
            byte[] strParam = new byte[0];
            cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);
            mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "GET_LOG_DATA", mDevId, strParam);
            Session["operation"] = GET_LOG_DATA;

            GetSLogBtn.Enabled = false;
            GetLogBtn.Enabled = false;
            ClearBtn.Enabled = false;
            Timer.Enabled = true;
        }
        catch (Exception ex)
        {
            StatusTxt.Text = "Fail! Get Log Data! " + ex.ToString();
        }

    }
    protected void GetSLogBtn_Click(object sender, EventArgs e)
    {

        string sBeginDate = BeginDate.Text;
        string sEndDate = EndDate.Text;
        JObject vResultJson = new JObject();
        FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
        DateTime dtBegin, dtEnd;
        if (sBeginDate.Length > 0)
        {
            try
            {
                dtBegin = Convert.ToDateTime(sBeginDate);
                sBeginDate = FKWebTools.GetFKTimeString14(dtBegin);
                vResultJson.Add("begin_time", sBeginDate);

            }
            catch
            {

                BeginDate.Text = "";
            }
        }

        if (sEndDate.Length > 0)
        {
            try
            {
                dtEnd = Convert.ToDateTime(sEndDate);
                sEndDate = FKWebTools.GetFKTimeString14(dtEnd);
                vResultJson.Add("end_time", sEndDate);

            }
            catch
            {

                EndDate.Text = "";
            }
        }

        try
        {
            string sFinal = vResultJson.ToString(Formatting.None);
            byte[] strParam = new byte[0];
            cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);
            mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "GET_SLOG_DATA", mDevId, strParam);
            Session["operation"] = GET_SLOG_DATA;

            GetSLogBtn.Enabled = false;
            GetLogBtn.Enabled = false;
            ClearBtn.Enabled = false;
            Timer.Enabled = true;
        }
        catch (Exception ex)
        {
            StatusTxt.Text = "Fail! Get SLog Data! " + ex.ToString();
        }

    }

    protected void ClearBtn_Click(object sender, EventArgs e)
    {
        try
        {
            mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "CLEAR_LOG_DATA", mDevId, null);
            StatusTxt.Text = "Success : All of log data has been deleted!";
            GetSLogBtn.Enabled = false;
            GetLogBtn.Enabled = false;
            ClearBtn.Enabled = false;
            Timer.Enabled = true;
        }
        catch (Exception ex)
        {
            StatusTxt.Text = "Error: All of log data delete operation failed!";
        }
    }
    protected void Show_Image_Timer_Watch(object sender, EventArgs e)
    {
        ShowImageTimer.Enabled = false;
        showLogImage();
    }

    protected void Timer_Watch(object sender, EventArgs e)
    {

        StatusTxt.Text = "Timer_Watch  ";

        if ((int)Session["operation"] == GET_LOG_DATA)
            BindGridView();
        else if ((int)Session["operation"] == GET_SLOG_DATA)
            SBindGridView();
        //showLogImage();
        string sTransId = "";
        if ((int)Session["operation"] == GET_LOG_IMAGE)
        {
            sTransId = mGetImageTransIdTxt.Text;
        }
        if ((int)Session["operation"] == GET_LOG_DATA || (int)Session["operation"] == GET_SLOG_DATA)
        {
            sTransId = mTransIdTxt.Text;
        }

        if (sTransId.Length == 0)
            return;

        string sSql = "select status from tbl_fkcmd_trans where trans_id='" + sTransId + "'";
        SqlCommand sqlCmd = new SqlCommand(sSql, msqlConn);
        SqlDataReader sqlReader = sqlCmd.ExecuteReader();
        try
        {

            if (sqlReader.HasRows)
            {
                if (sqlReader.Read())
                    if (sqlReader.GetString(0) == "RESULT" || sqlReader.GetString(0) == "CANCELLED")
                    {
                        StatusTxt.Text = sqlReader.GetString(0) + " : OK!";
                        GetSLogBtn.Enabled = true;
                        GetLogBtn.Enabled = true;
                        ClearBtn.Enabled = true;
                        Timer.Enabled = false;
                        sqlReader.Close();
                        if ((int)Session["operation"] == GET_LOG_IMAGE)
                        {
                            ShowImageTimer.Enabled = true;

                            return;
                        }
                        if ((int)Session["operation"] == GET_LOG_DATA)
                        {
                            BindGridView();
                            return;
                        }
                        if ((int)Session["operation"] == GET_SLOG_DATA)
                        {
                            SBindGridView();
                            return;
                        }
                    }
                    else
                        StatusTxt.Text = "       Device Status: " + sqlReader.GetString(0) + "&nbsp;&nbsp;&nbsp; Current Time :" + DateTime.Now.ToString("HH:mm:ss tt");
            }
            sqlReader.Close();
        }
        catch (Exception ex)
        {
            StatusTxt.Text = StatusTxt.Text + ex.ToString();

        }
    }

    protected void gvLog_SelectedIndexChanged(object sender, EventArgs e)
    {
        if ((int)Session["operation"] == GET_LOG_DATA || (int)Session["operation"] == GET_LOG_IMAGE)
            GetLogImage(gvLog.SelectedIndex);
    }

    private void GetLogImage(int selectedIndex)
    {
        string sLogTime;
        DateTime dtLogTime;
        JObject vResultJson = new JObject();
        FKWebCmdTrans cmdTrans = new FKWebCmdTrans();

        sLogTime = gvLog.Rows[selectedIndex].Cells[5].Text;
        dtLogTime = Convert.ToDateTime(sLogTime);
        sLogTime = FKWebTools.GetFKTimeString14(dtLogTime);

        vResultJson.Add("user_id", gvLog.Rows[selectedIndex].Cells[2].Text);
        vResultJson.Add("log_time", sLogTime);
        string sFinal = vResultJson.ToString(Formatting.None);
        byte[] strParam = new byte[0];
        cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);
        mGetImageTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "GET_LOG_IMAGE", mDevId, strParam);
        Session["operation"] = GET_LOG_IMAGE;
        GetSLogBtn.Enabled = false;
        GetLogBtn.Enabled = false;
        ClearBtn.Enabled = false;
        Timer.Enabled = true;
        // StatusTxt.Text = "OK:" + mTransIdTxt.Text;
    }
    private void showLogImage()
    {
        UserPhoto.ImageUrl = "Log_ImageHandler.ashx?trans_id=" + mGetImageTransIdTxt.Text;
    }
}