<%@ WebHandler Language="C#" Class="ImageHandler" %>

using System;
using System.Web;
using System.Data.SqlClient;
using FKWeb;
using System.Data;
using System.Configuration;
public class ImageHandler : IHttpHandler {

    SqlConnection msqlConn;
    FKWebCmdTrans mTrans = new FKWebCmdTrans();
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "image/jpeg";

        String device_id = context.Request.QueryString["device_id"];
        String user_id = context.Request.QueryString["user_id"];
        String io_time = context.Request.QueryString["io_time"];

        string strSelectCmd = "SELECT log_image FROM tbl_realtime_glog where device_id=@device_id and user_id=@user_id and io_time=@io_time";
        String msDbConn = ConfigurationManager.ConnectionStrings["SqlConnFkWeb"].ConnectionString.ToString();
        msqlConn = new SqlConnection(msDbConn);
        msqlConn.Open();
        SqlDataReader reader = null;
        SqlCommand command = null;
        try
        {
            command = new SqlCommand(strSelectCmd, msqlConn);
            command.CommandType = CommandType.Text;
            command.Parameters.Add("@device_id", SqlDbType.VarChar).Value = device_id;
            command.Parameters.Add("@user_id", SqlDbType.VarChar).Value = user_id;
            command.Parameters.Add("@io_time", SqlDbType.VarChar).Value = io_time;
            reader = command.ExecuteReader();
            reader.Read();
            byte[] image = (byte[])reader[0];
            context.Response.BinaryWrite(image);
            reader.Close();
            msqlConn.Close();//.Dispose();
            msqlConn.Dispose();
            mTrans.PrintDebugMsg("Real-time glog ","----------------------------------------->");
        }
        catch(Exception e)
        {
            mTrans.PrintDebugMsg("Real-time glog ", "-------------------- Exception --------------------->"+e.ToString());
            reader.Close();
            msqlConn.Close();
            msqlConn.Dispose();
        }
        
    }
 
    public bool IsReusable {
        get {
            return false;
        }
    }

}