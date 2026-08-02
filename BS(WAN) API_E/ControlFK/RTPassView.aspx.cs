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
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using FKWeb;
public partial class RTLogView : System.Web.UI.Page
{
      string mDevId;
      SqlConnection msqlConn;
    protected void Page_Load(object sender, EventArgs e)
    {
        gvDoorstatus.AllowSorting = true;
        msqlConn = FKWebTools.GetDBPool();
        // Initialize the sorting expression. 
        ViewState["SortExpression"] = "update_time ASC";
       
        gvDoorstatus.AllowPaging = true;
        gvDoorstatus.PageSize = 20;
        
        
        gvDoorstatus.PageIndex = Convert.ToInt32(Session["PageIndex"]); 

    }

    private void BindGridView()
    {
        // Get the connection string from Web.config.  
        // When we use Using statement,  
        // we don't need to explicitly dispose the object in the code,  
        // the using statement takes care of it. 
        try
        {
           // using (SqlConnection conn = new SqlConnection(ConfigurationManager.ConnectionStrings["SqlConnFkWeb"].ToString()))
            {
                // Create a DataSet object. 
                DataSet dsLog = new DataSet();


                // Create a SELECT query. 
                string strSelectCmd = "SELECT update_time, device_id, door_status FROM tbl_realtime_doorstatus where update_time >= '" + Session["run_time"] + "'";
                //string strSelectCmd = "SELECT update_time, device_id, user_id, verify_mode, io_mode, io_time FROM tbl_realtime_glog ";

                // Create a SqlDataAdapter object 
                // SqlDataAdapter represents a set of data commands and a  
                // database connection that are used to fill the DataSet and  
                // update a SQL Server database.  
                SqlDataAdapter da = new SqlDataAdapter(strSelectCmd, msqlConn);


                // Open the connection 
                //conn.Open();


                // Fill the DataTable named "Person" in DataSet with the rows 
                // returned by the query.new n 
                da.Fill(dsLog, "tbl_realtime_doorstatus");


                // Get the DataView from Person DataTable. 
                DataView dvLog = dsLog.Tables["tbl_realtime_doorstatus"].DefaultView;


                // Set the sort column and sort order. 
                dvLog.Sort = ViewState["SortExpression"].ToString();
                
                // Bind the GridView control. 
                gvDoorstatus.DataSource = dvLog;
                gvDoorstatus.DataBind();

                int pageCount = gvDoorstatus.PageCount;
                int totalCount = gvDoorstatus.PageSize * (pageCount - 1);


                StatusTxt.Text = "       Total Count : " + (dvLog.Count) + "&nbsp;&nbsp;&nbsp; Current Time :" + DateTime.Now.ToString("HH:mm:ss tt");
            }
        }catch(Exception ex){
            StatusTxt.Text = ex.ToString();
        }

    }

    protected void gvDoorstatus_PageIndexChanging(object sender, GridViewPageEventArgs e)
    {
        // Set the index of the new display page.  
        gvDoorstatus.PageIndex = e.NewPageIndex;

        Session["PageIndex"] = e.NewPageIndex;

        gvDoorstatus.SelectedIndex = -1;
        // Rebind the GridView control to  
        // show data in the new page. 
        BindGridView();
    } 


    protected void gvDoorstatus_Sorting(object sender, GridViewSortEventArgs e)
    {
        string[] strSortExpression = ViewState["SortExpression"].ToString().Split(' ');


        // If the sorting column is the same as the previous one,  
        // then change the sort order. 
        if (strSortExpression[0] == e.SortExpression)
        {
            if (strSortExpression[1] == "ASC")
            {
                ViewState["SortExpression"] = e.SortExpression + " " + "DESC";
            }
            else
            {
                ViewState["SortExpression"] = e.SortExpression + " " + "ASC";
            }
        }
        // If sorting column is another column,   
        // then specify the sort order to "Ascending". 
        else
        {
            ViewState["SortExpression"] = e.SortExpression + " " + "ASC";
        }

        //Label1.Text = ViewState["SortExpression"].ToString();
        // Rebind the GridView control to show sorted data. 
        BindGridView();
    }


    protected void goback_Click(object sender, EventArgs e)
    {
        Response.Redirect("Default.aspx");
    }

   protected void Timer_Watch(object sender, EventArgs e)
    {
        //label is on first panel
        BindGridView();
    }
}
