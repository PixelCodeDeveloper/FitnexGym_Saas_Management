<%@ WebHandler Language="C#" Class="ImageHandler" %>

using System;
using System.Web;
using System.Data.SqlClient;
using FKWeb;
using System.Data;
using System.Configuration;
using System.IO;
using System.Web;
public class ImageHandler : IHttpHandler {

    SqlConnection msqlConn;
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "image/jpeg";

        String trans_id = context.Request.QueryString["trans_id"];
        FKWebCmdTrans mTrans = new FKWebCmdTrans();
        string strSelectCmd = "SELECT cmd_result FROM tbl_fkcmd_trans_cmd_result where trans_id=@trans_id";
        String msDbConn = ConfigurationManager.ConnectionStrings["SqlConnFkWeb"].ConnectionString.ToString();
        msqlConn = new SqlConnection(msDbConn);
        msqlConn.Open();
        SqlDataReader reader = null;
        SqlCommand command = null;
        try
        {
            command = new SqlCommand(strSelectCmd, msqlConn);
            command.CommandType = CommandType.Text;
            command.Parameters.Add("@trans_id", SqlDbType.VarChar).Value = trans_id;
            reader = command.ExecuteReader();
            reader.Read();
            byte[] bytResultBin = (byte[])reader[0];
            byte[] bytResultImage = new byte[0];
            string sResultText;


            mTrans.GetStringAndBinaryFromBSCommBuffer(bytResultBin, out sResultText, out bytResultImage);
            int vnBinLen = FKWebTools.GetBinarySize(bytResultImage, out bytResultImage);
            
            context.Response.BinaryWrite(bytResultImage);
            reader.Close();
            msqlConn.Close();//.Dispose();
        }
        catch(Exception e)
        {
            reader.Close();
            msqlConn.Close();
        }
        
    }
 
    public bool IsReusable {
        get {
            return false;
        }
    }

}