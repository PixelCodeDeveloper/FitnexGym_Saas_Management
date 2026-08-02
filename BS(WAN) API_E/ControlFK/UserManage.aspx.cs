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
using System.Data.SqlClient;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.IO;
using FKWeb;

public partial class UserManage : System.Web.UI.Page
{
    SqlConnection msqlConn;
    string mDevId;
    string mDevModel;
    string mUserId;
    string mTransId;

    const int GET_USER_LIST = 0;
    const int GET_USER_INFO = 1;
    const int SET_USER_INFO = 2;
    const int DEL_USER_INFO = 3;
    const int ALL_DEL = 4;
    const int ALL_MANAGER_DEL = 5;
    const int ENTER_ENROLL = 6;

    protected void Page_Load(object sender, EventArgs e)
    {
        mDevId = (string)Session["dev_id"];
        mDevModel = (string)Session["dev_model"];

        DevID.Text = mDevId;

        msqlConn = FKWebTools.GetDBPool();

        if (FKWebTools.mbDebugTest)
        {
            DebugTest();
        }
    }

    private void DebugTest()
    {
        Session["trans_id"] = FKWebTools.MakeCmd(msqlConn, "GET_USER_ID_LIST", "DC644064CD406C36", null);
        Session["operation"] = GET_USER_LIST;

        FKWebTools.mbDebugTest = false;
    }


    public void refresh_page()
    {
        UserList.DataSource = GetUserList();
        UserList.DataTextField = "UserName";
        UserList.DataValueField = "UserID";

        UserList.DataBind();

        Device_List.DataSource = DetectDevice();
        Device_List.DataTextField = "DeviceNameField";
        Device_List.DataValueField = "DeviceIDField";

        Device_List.DataBind();

        try
        {
            if (mDevId.Length != 0)
            {
                Device_List.SelectedIndex = Device_List.Items.IndexOf(Device_List.Items.FindByValue(mDevId));
            }
        }
        catch
        {
            Device_List.SelectedIndex = 0;
        }
    }



    public ICollection GetUserList()
    {
        string sSql;
        string trans_id = mTransIdTxt.Text;
        if (trans_id.Length == 0)
            trans_id = (string)Session["trans_id"];
        sSql = "select DISTINCT user_id from tbl_fkcmd_trans_cmd_result_user_id_list where trans_id='" + trans_id + "'";
        SqlCommand sqlCmd = new SqlCommand(sSql, msqlConn);
        SqlDataReader sqlReader = sqlCmd.ExecuteReader();

        DataTable dt = new DataTable();
        int mCount = 0;
        dt.Columns.Add(new DataColumn("UserName", typeof(String)));
        dt.Columns.Add(new DataColumn("UserID", typeof(String)));

        if (sqlReader.HasRows)
        {
            while (sqlReader.Read())
            {
                mCount++;
                dt.Rows.Add(CreateRow(sqlReader.GetString(0), sqlReader.GetString(0), dt));
            }
            StatusTxt.Text = " Just finished for reading user list from device!, you can select user id for looking user info!";

        }
        sqlReader.Close();
        DataView dv = new DataView(dt);
        return dv;

    }

    public ICollection DetectDevice()
    {
        string sSql;

        sSql = "select * from tbl_fkdevice_status";
        SqlCommand sqlCmd = new SqlCommand(sSql, msqlConn);
        SqlDataReader sqlReader = sqlCmd.ExecuteReader();

        DataTable dt = new DataTable();
        int mCount = 0;
        dt.Columns.Add(new DataColumn("DeviceNameField", typeof(String)));
        dt.Columns.Add(new DataColumn("DeviceIDField", typeof(String)));

        dt.Rows.Add(CreateRow("none", null, dt));

        if (sqlReader.HasRows)
        {
            while (sqlReader.Read())
            {
                mCount++;
                dt.Rows.Add(CreateRow(sqlReader.GetString(1), sqlReader.GetString(0), dt));
            }
        }
        sqlReader.Close();
        StatusTxt.Text = "Device Count: " + mCount;
        DataView dv = new DataView(dt);
        return dv;

    }

    DataRow CreateRow(String Text, String Value, DataTable dt)
    {

        DataRow dr = dt.NewRow();

        dr[0] = Text;
        dr[1] = Value;

        return dr;

    }

    protected void goback_Click(object sender, EventArgs e)
    {
        Response.Redirect("Default.aspx");
    }

    protected void RefreshBtn_Click(object sender, EventArgs e)
    {
        refresh_page();
    }

    protected void GetInfoBtn_Click(object sender, EventArgs e)
    {
        //    DisplayUserInfo();
        //     return;

        byte[] mByteParam = new byte[0];
        string mStrParam;
        try
        {
            Enables(false);
            JObject vResultJson = new JObject();
            FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
            mUserId = UserList.SelectedItem.Value;
            string sDevId = Device_List.SelectedItem.Value;

            if (sDevId != null)
            {
                Session["dev_id"] = sDevId;
                mDevId = (string)Session["dev_id"];
            }

            vResultJson.Add("user_id", mUserId);
            mStrParam = vResultJson.ToString(Formatting.None);
            UserPhoto.ImageUrl = null;
            cmdTrans.CreateBSCommBufferFromString(mStrParam, out mByteParam);
            mTransId = FKWebTools.MakeCmd(msqlConn, "GET_USER_INFO", mDevId, mByteParam);
            mTransIdTxt.Text = mTransId;
            Session["operation"] = GET_USER_INFO;

            Editable(false, "");


        }
        catch (Exception ex)
        {
            StatusTxt.Text = ex.ToString();
        }
    }

    private void init_userInfo()
    {
        UserID.Text = "";
        UserName.Text = "";
        CardNum.Text = "";
        Password.Text = "";
        VID.Text = "";
        UserPhoto.ImageUrl = null;

        //int vnBinCount = FKWebTools.BACKUP_MAX + 1;
        //int[] vnBackupNumbers = new int[vnBinCount];

        for (int i = 0; i <= FKWebTools.BACKUP_FP_9; i++)
        {
            FKWebTools.mFinger[i] = new byte[0];
        }
        for (int i = FKWebTools.BACKUP_PALM_1; i <= FKWebTools.BACKUP_PALM_2; i++)
        {
            FKWebTools.mPalm[i - FKWebTools.BACKUP_PALM_1] = new byte[0];
        }
        FKWebTools.mFace = new byte[0];
        FKWebTools.mPhoto = new byte[0];

    }
    private void Editable(bool flag, string userID)
    {
        //string mUserId = 
        UserID.Enabled = flag;
        UserName.Enabled = flag;
        CardNum.Enabled = flag;
        Password.Enabled = flag;
        UserPriv.Enabled = flag;
        VID.Enabled = flag;

        if (userID.Length <= 0) userID = "1";
        string sDevId = Device_List.SelectedItem.Value;

        if (sDevId != null)
        {
            Session["dev_id"] = sDevId;
            mDevId = (string)Session["dev_id"];
        }
        UserPhoto.ImageUrl = ".\\photo\\" + mDevId + "_" + userID + ".jpg";
        //StatusTxt.Text = Server.MapPath(".") + "\\photo\\" + mDevId + "_" + userID + ".jpg";
    }

    private void DisplayUserInfo()
    {
        string sTransId = mTransIdTxt.Text;
        FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
        JObject vResultJson;// = new JObject();
        mUserId = UserList.SelectedItem.Value;

        string sCmdCode = "";
        if (sTransId.Length == 0)
            return;
        string sSql = "select trans_id, cmd_code from tbl_fkcmd_trans where trans_id='" + sTransId + "' AND status='RESULT'";
        SqlCommand sqlCmd = new SqlCommand(sSql, msqlConn);
        SqlDataReader sqlReader = sqlCmd.ExecuteReader();

        sTransId = "";
        if (sqlReader.HasRows)
        {
            if (sqlReader.Read())
            {
                sTransId = sqlReader.GetString(0);
                sCmdCode = sqlReader.GetString(1);
            }
        }
        sqlReader.Close();

        if (sTransId.Length == 0)
            return;

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

        if (string.IsNullOrEmpty(mDevModel))
            cmdTrans.GetStringAndBinaryFromBSCommBuffer(bytCmdResult, out sResultText, out bytResultBin);
        else
            sResultText = System.Text.Encoding.UTF8.GetString(bytCmdResult);

        vResultJson = JObject.Parse(sResultText);

        UserID.Text = vResultJson["user_id"].ToString();
        UserName.Text = vResultJson["user_name"].ToString();

        string sUserpriv = vResultJson["user_privilege"].ToString();
        UserPriv.SelectedIndex = UserPriv.Items.IndexOf(UserPriv.Items.FindByText(sUserpriv));
        try
        {
            string sUserVID = vResultJson["user_vid"].ToString();
            VID.Text = sUserVID;
        }
        catch (Exception e)
        {
        }
        int vnBinIndex = 0;
        int vnBinCount = FKWebTools.BACKUP_MAX + 1;
        int[] vnBackupNumbers = new int[vnBinCount];

        for (int i = 0; i < vnBinCount; i++)
        {
            vnBackupNumbers[i] = -1;
            if (i <= FKWebTools.BACKUP_FP_9)
                FKWebTools.mFinger[i] = new byte[0];
            if ((i >= FKWebTools.BACKUP_PALM_1) && (i <= FKWebTools.BACKUP_PALM_2))
                FKWebTools.mPalm[i - FKWebTools.BACKUP_PALM_1] = new byte[0];
        }
        FKWebTools.mFace = new byte[0];
        FKWebTools.mPhoto = new byte[0];


        if (string.IsNullOrEmpty(mDevModel))
        {
            try
            {
                string vStrUserPhotoBinIndex = vResultJson["user_photo"].ToString(); //aCmdParamJson.get("user_photo", "").asString();
                if (vStrUserPhotoBinIndex.Length != 0)
                {
                    vnBinIndex = FKWebTools.GetBinIndex(vStrUserPhotoBinIndex) - 1;
                    vnBackupNumbers[vnBinIndex] = FKWebTools.BACKUP_USER_PHOTO;
                }

            }
            catch (Exception e)
            {

            }

            string enroll_data = vResultJson["enroll_data_array"].ToString();

            if (enroll_data.Equals("null") || enroll_data == "null" || enroll_data.Length == 0)
            {
                StatusTxt.Text = "Enroll data is empty !!!";
                return;
            }

            JArray vEnrollDataArrayJson = JArray.Parse(vResultJson["enroll_data_array"].ToString());

            foreach (JObject content in vEnrollDataArrayJson.Children<JObject>())
            {
                int vnBackupNumber = Convert.ToInt32(content["backup_number"].ToString());

                string vStrBinIndex = content["enroll_data"].ToString();
                vnBinIndex = FKWebTools.GetBinIndex(vStrBinIndex) - 1;
                vnBackupNumbers[vnBinIndex] = vnBackupNumber;

            }
            Fp.Checked = false;
            Face.Checked = false;
            Palm.Checked = false;
            Password.Text = "";
            CardNum.Text = "";
            for (int i = 0; i < vnBinCount; i++)
            {
                if (vnBackupNumbers[i] == -1) continue;

                if (vnBackupNumbers[i] == FKWebTools.BACKUP_USER_PHOTO)
                {
                    byte[] bytResultBinParam = new byte[0];
                    int vnBinLen = FKWebTools.GetBinarySize(bytResultBin, out bytResultBin);
                    string AbsImgUri = Server.MapPath(".") + "\\photo\\" + mDevId + "_" + mUserId + ".jpg";
                    string relativeImgUrl = ".\\photo\\" + mDevId + "_" + mUserId + ".jpg";
                    FKWebTools.GetBinaryData(bytResultBin, vnBinLen, out bytResultBinParam, out bytResultBin);
                    FKWebTools.mPhoto = new byte[vnBinLen];

                    Array.Copy(bytResultBinParam, FKWebTools.mPhoto, vnBinLen);
                    try
                    {
                        FileStream fs = new FileStream(AbsImgUri, FileMode.Create, FileAccess.Write);
                        fs.Write(bytResultBinParam, 0, bytResultBinParam.Length);
                        fs.Close();
                    }
                    catch
                    { }
                    UserPhoto.ImageUrl = relativeImgUrl;

                }
                if (vnBackupNumbers[i] == FKWebTools.BACKUP_PSW)
                {
                    byte[] bytResultBinParam = new byte[0];
                    Password.Text = cmdTrans.GetStringFromBSCommBuffer(bytResultBin);
                    int vnBinLen = FKWebTools.GetBinarySize(bytResultBin, out bytResultBin);
                    FKWebTools.GetBinaryData(bytResultBin, vnBinLen, out bytResultBinParam, out bytResultBin);

                }
                if (vnBackupNumbers[i] == FKWebTools.BACKUP_CARD)
                {
                    byte[] bytResultBinParam = new byte[0];
                    CardNum.Text = cmdTrans.GetStringFromBSCommBuffer(bytResultBin);
                    int vnBinLen = FKWebTools.GetBinarySize(bytResultBin, out bytResultBin);
                    FKWebTools.GetBinaryData(bytResultBin, vnBinLen, out bytResultBinParam, out bytResultBin);
                }

                if (vnBackupNumbers[i] == FKWebTools.BACKUP_FACE)
                {
                    byte[] bytResultBinParam = new byte[0];
                    int vnBinLen = FKWebTools.GetBinarySize(bytResultBin, out bytResultBin);
                    FKWebTools.GetBinaryData(bytResultBin, vnBinLen, out bytResultBinParam, out bytResultBin);
                    Face.Checked = true;
                    FKWebTools.mFace = new byte[vnBinLen];
                    Array.Copy(bytResultBinParam, FKWebTools.mFace, vnBinLen);
                }

                if (vnBackupNumbers[i] >= FKWebTools.BACKUP_PALM_1 && vnBackupNumbers[i] <= FKWebTools.BACKUP_PALM_2)
                {
                    byte[] bytResultBinParam = new byte[0];
                    int vnBinLen = FKWebTools.GetBinarySize(bytResultBin, out bytResultBin);
                    FKWebTools.GetBinaryData(bytResultBin, vnBinLen, out bytResultBinParam, out bytResultBin);
                    Palm.Checked = true;
                    FKWebTools.mPalm[vnBackupNumbers[i] - FKWebTools.BACKUP_PALM_1] = new byte[vnBinLen];
                    Array.Copy(bytResultBinParam, FKWebTools.mPalm[vnBackupNumbers[i] - FKWebTools.BACKUP_PALM_1], vnBinLen);
                }

                if (vnBackupNumbers[i] >= FKWebTools.BACKUP_FP_0 && vnBackupNumbers[i] <= FKWebTools.BACKUP_FP_9)
                {
                    byte[] bytResultBinParam = new byte[0];
                    int vnBinLen = FKWebTools.GetBinarySize(bytResultBin, out bytResultBin);
                    FKWebTools.GetBinaryData(bytResultBin, vnBinLen, out bytResultBinParam, out bytResultBin);
                    Fp.Checked = true;
                    FKWebTools.mFinger[vnBackupNumbers[i]] = new byte[vnBinLen];
                    Array.Copy(bytResultBinParam, FKWebTools.mFinger[vnBackupNumbers[i]], vnBinLen);
                }
            }
        }
        else
        {
            Fp.Checked = false;
            Face.Checked = false;
            Palm.Checked = false;
            Password.Text = "";
            CardNum.Text = "";

            string enroll_data = vResultJson["enroll_data_array"].ToString();

            if (enroll_data.Equals("null") || enroll_data == "null" || enroll_data.Length == 0)
            {
                StatusTxt.Text = "Enroll data is empty !!!";
                return;
            }

            JArray vEnrollDataArrayJson = JArray.Parse(vResultJson["enroll_data_array"].ToString());

            foreach (JObject content in vEnrollDataArrayJson.Children<JObject>())
            {
                int vnBackupNumber = Convert.ToInt32(content["backup_number"].ToString());

                if (vnBackupNumber == FKWebTools.BACKUP_PSW)
                {
                    Password.Text = content["enroll_data"].ToString();
                }
                else if (vnBackupNumber == FKWebTools.BACKUP_CARD)
                {
                    CardNum.Text = content["enroll_data"].ToString();
                }
                else if (vnBackupNumber == FKWebTools.BACKUP_FACE)
                {
                    Face.Checked = true;
                    FKWebTools.mFace = System.Text.Encoding.UTF8.GetBytes(content["enroll_data"].ToString());
                }
                else if (vnBackupNumber >= FKWebTools.BACKUP_PALM_1 && vnBackupNumber <= FKWebTools.BACKUP_PALM_2)
                {
                    Palm.Checked = true;
                    FKWebTools.mPalm[vnBackupNumber - FKWebTools.BACKUP_PALM_1] = System.Text.Encoding.UTF8.GetBytes(content["enroll_data"].ToString());
                }
                else if (vnBackupNumber >= FKWebTools.BACKUP_FP_0 && vnBackupNumber <= FKWebTools.BACKUP_FP_9)
                {
                    Fp.Checked = true;
                    FKWebTools.mFinger[vnBackupNumber] = System.Text.Encoding.UTF8.GetBytes(content["enroll_data"].ToString());
                }
            }

            try
            {
                string vsUserPhoto = vResultJson["user_photo"].ToString();
                string AbsImgUri = Server.MapPath(".") + "\\photo\\" + mDevId + "_" + mUserId + ".jpg";
                string relativeImgUrl = ".\\photo\\" + mDevId + "_" + mUserId + ".jpg";

                FKWebTools.mPhoto = System.Text.Encoding.UTF8.GetBytes(vsUserPhoto);
                FileStream fs = new FileStream(AbsImgUri, FileMode.Create, FileAccess.Write);
                fs.Write(FKWebTools.mPhoto, 0, FKWebTools.mPhoto.Length);
                fs.Close();
                UserPhoto.ImageUrl = relativeImgUrl;
            }
            catch { }
        }
    }

    protected void SetInfoBtn_Click(object sender, EventArgs e)
    {
        try
        {
            Session["operation"] = SET_USER_INFO;
            JObject vResultJson = new JObject();
            JArray vEnrollDataArrayJson = new JArray();
            FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
            string sUserPwd = Password.Text;
            string sUserCard = CardNum.Text;
            int index = 1;
            string sUserId = UserID.Text;
            string sUserName = UserName.Text;
            string sUserPriv = UserPriv.SelectedItem.Text;
            string sUserVID = VID.Text;
            string sDevId = Device_List.SelectedItem.Value;

            if (sDevId != null)
            {
                Session["dev_id"] = sDevId;
                mDevId = (string)Session["dev_id"];
            }

            if (sUserVID.Length == 0)
                sUserVID = " ";

            UserPhoto.ImageUrl = ".\\photo\\" + mDevId + "_" + sUserId + ".jpg";

            vResultJson.Add("user_id", sUserId);
            vResultJson.Add("user_name", sUserName);
            vResultJson.Add("user_privilege", sUserPriv);
            vResultJson.Add("user_vid", sUserVID);

            if (FKWebTools.mPhoto.Length > 0)
                vResultJson.Add("user_photo", FKWebTools.GetBinIndexString(index++));

            for (int nIndex = 0; nIndex <= FKWebTools.BACKUP_FP_9; nIndex++)
            {

                if (FKWebTools.mFinger[nIndex].Length > 0)
                {
                    JObject vEnrollDataJson = new JObject();
                    vEnrollDataJson.Add("backup_number", nIndex);
                    vEnrollDataJson.Add("enroll_data", FKWebTools.GetBinIndexString(index++));
                    vEnrollDataArrayJson.Add(vEnrollDataJson);
                }

            }
            for (int nIndex = FKWebTools.BACKUP_PALM_1; nIndex <= FKWebTools.BACKUP_PALM_2; nIndex++)
            {

                if (FKWebTools.mPalm[nIndex - FKWebTools.BACKUP_PALM_1].Length > 0)
                {
                    JObject vEnrollDataJson = new JObject();
                    vEnrollDataJson.Add("backup_number", nIndex);
                    vEnrollDataJson.Add("enroll_data", FKWebTools.GetBinIndexString(index++));
                    vEnrollDataArrayJson.Add(vEnrollDataJson);
                }

            }
            if (sUserPwd.Length > 0)
            {
                JObject vEnrollDataJson = new JObject();
                vEnrollDataJson.Add("backup_number", FKWebTools.BACKUP_PSW);
                vEnrollDataJson.Add("enroll_data", FKWebTools.GetBinIndexString(index++));
                vEnrollDataArrayJson.Add(vEnrollDataJson);
            }

            if (sUserCard.Length > 0)
            {
                JObject vEnrollDataJson = new JObject();
                vEnrollDataJson.Add("backup_number", FKWebTools.BACKUP_CARD);
                vEnrollDataJson.Add("enroll_data", FKWebTools.GetBinIndexString(index++));
                vEnrollDataArrayJson.Add(vEnrollDataJson);
            }
            if (FKWebTools.mFace.Length > 0)
            {
                JObject vEnrollDataJson = new JObject();
                vEnrollDataJson.Add("backup_number", FKWebTools.BACKUP_FACE);
                vEnrollDataJson.Add("enroll_data", FKWebTools.GetBinIndexString(index++));
                vEnrollDataArrayJson.Add(vEnrollDataJson);
            }

            vResultJson.Add("enroll_data_array", vEnrollDataArrayJson);
            string sFinal = vResultJson.ToString(Formatting.None);
            //DevID.Text = sFinal;
            byte[] binData = new byte[0];
            byte[] strParam = new byte[0];

            if (FKWebTools.mPhoto.Length > 0)
            {
                FKWebTools.AppendBinaryData(ref binData, FKWebTools.mPhoto);
            }

            for (int nIndex = 0; nIndex <= FKWebTools.BACKUP_FP_9; nIndex++)
            {
                if (FKWebTools.mFinger[nIndex].Length > 0)
                {
                    FKWebTools.AppendBinaryData(ref binData, FKWebTools.mFinger[nIndex]);
                }
            }
            //
            for (int nIndex = FKWebTools.BACKUP_PALM_1; nIndex <= FKWebTools.BACKUP_PALM_2; nIndex++)
            {

                if (FKWebTools.mPalm[nIndex - FKWebTools.BACKUP_PALM_1].Length > 0)
                {
                    FKWebTools.AppendBinaryData(ref binData, FKWebTools.mPalm[nIndex - FKWebTools.BACKUP_PALM_1]);
                }

            }
            if (sUserPwd.Length > 0)
            {
                byte[] mPwdBin = new byte[0];
                cmdTrans.CreateBSCommBufferFromString(sUserPwd, out mPwdBin);
                FKWebTools.ConcateByteArray(ref binData, mPwdBin);
            }
            if (sUserCard.Length > 0)
            {
                byte[] mCardBin = new byte[0];
                cmdTrans.CreateBSCommBufferFromString(sUserCard, out mCardBin);
                FKWebTools.ConcateByteArray(ref binData, mCardBin);
            }
            if (FKWebTools.mFace.Length > 0)
            {
                FKWebTools.AppendBinaryData(ref binData, FKWebTools.mFace);
            }
            cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);

            FKWebTools.ConcateByteArray(ref strParam, binData);

            mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "SET_USER_INFO", mDevId, strParam);
            Enables(false);
        }
        catch (Exception ex)
        {
            StatusTxt.Text = ex.ToString();
        }

    }

    protected void DeleteUserBtn_Click(object sender, EventArgs e)
    {
        try
        {
            Session["operation"] = DEL_USER_INFO;
            string sUserId = UserList.SelectedItem.Value;
            string sDevId = Device_List.SelectedItem.Value;
            if (sDevId != null)
            {
                Session["dev_id"] = sDevId;
                mDevId = (string)Session["dev_id"];
            }
            FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
            JObject vResultJson = new JObject();
            vResultJson.Add("user_id", sUserId);
            string sFinal = vResultJson.ToString(Formatting.None);
            byte[] strParam = new byte[0];
            cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);
            mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "DELETE_USER", mDevId, strParam);
            Enables(false);
        }
        catch (Exception ex)
        {
            StatusTxt.Text = ex.ToString();
        }

    }
    protected void ClearBtn_Click(object sender, EventArgs e)
    {
        try
        {
            Session["operation"] = ALL_DEL;
            string sDevId = Device_List.SelectedItem.Value;

            if (sDevId != null)
            {
                Session["dev_id"] = sDevId;
                mDevId = (string)Session["dev_id"];
            }
            mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "CLEAR_ENROLL_DATA", mDevId, null);
            Enables(false);
        }
        catch (Exception ex)
        {
            StatusTxt.Text = ex.ToString();
        }
    }

    private void Enables(bool flag)
    {
        UserList.Enabled = flag;
        GetInfoBtn.Enabled = flag;
        SetInfoBtn.Enabled = false;
        DeleteUserBtn.Enabled = flag;
        ClearBtn.Enabled = flag;
        UpdateUserListBtn.Enabled = flag;
        NewBtn.Enabled = flag;
        ModifyBtn.Enabled = flag;
        ClearManagerBtn.Enabled = flag;
        Timer.Enabled = !flag;
    }

    protected void Timer_Watch(object sender, EventArgs e)
    {
        string sTransId = mTransIdTxt.Text;
        if (sTransId.Length == 0)
        {
            sTransId = (string)Session["trans_id"];
            if (sTransId.Length == 0)
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
                        //DevID.Text = Convert.ToString((int)Session["operation"]);
                        if ((int)Session["operation"] == GET_USER_INFO)
                        {
                            sqlReader.Close();
                            DisplayUserInfo();
                            ModifyBtn.Enabled = true;
                            return;
                        }
                        if ((int)Session["operation"] == GET_USER_LIST)
                        {
                            sqlReader.Close();

                            refresh_page();
                            return;
                        }
                        if ((int)Session["operation"] == ALL_MANAGER_DEL)
                        {
                            sqlReader.Close();
                            return;
                        }
                        if ((int)Session["operation"] == ALL_DEL)
                        {
                            sqlReader.Close();
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
        UserPhoto.ImageUrl = ".\\photo\\" + mDevId + "_" + UserID.Text + ".jpg";
    }
    protected void UpdateUserListBtn_Click(object sender, EventArgs e)
    {
        Enables(false);
        Session["operation"] = GET_USER_LIST;
        string sDevId = Device_List.SelectedItem.Value;

        if (sDevId != null)
        {
            Session["dev_id"] = sDevId;
            mDevId = (string)Session["dev_id"];
        }
        mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "GET_USER_ID_LIST", mDevId, null);
        Editable(false, "");
    }

    private int GetLastUserIndex()
    {
        string sSql;
        SqlCommand sqlCmd;//= new SqlCommand(sSql, msqlConn);
        SqlDataReader sqlReader;// = sqlCmd.ExecuteReader();

        for (int i = 1; i < 10000; i++)
        {
            sSql = "select user_id from tbl_fkcmd_trans_cmd_result_user_id_list where device_id = '" + mDevId + "' and user_id=" + i;
            sqlCmd = new SqlCommand(sSql, msqlConn);
            sqlReader = sqlCmd.ExecuteReader();
            if (!sqlReader.HasRows)
            {
                sqlReader.Close();
                return i;
            }
            sqlReader.Close();
        }
        return 0;
    }

    protected void NewBtn_Click(object sender, EventArgs e)
    {

        init_userInfo();
        SetInfoBtn.Enabled = true;
        UserID.Text = Convert.ToString(GetLastUserIndex());
        Editable(true, UserID.Text);
    }
    protected void ModifyBtn_Click(object sender, EventArgs e)
    {
        Editable(true, UserID.Text);
        SetInfoBtn.Enabled = true;
    }
    protected void EnterEnrollBtn_Click(object sender, EventArgs e)
    {
        try
        {
            Session["operation"] = ENTER_ENROLL;
            string sUserId = EnterEnrollID.Text;
            int backup_number = Convert.ToInt32(EnterEnrollBackupNo.SelectedItem.Value);
            string sDevId = Device_List.SelectedItem.Value;
            if (sDevId != null)
            {
                Session["dev_id"] = sDevId;
                mDevId = (string)Session["dev_id"];
            }
            FKWebCmdTrans cmdTrans = new FKWebCmdTrans();
            JObject vResultJson = new JObject();
            JObject vjobjparam = new JObject();
            vResultJson.Add("cmd", "enter_enroll");
            vjobjparam.Add("user_id", sUserId);
            vjobjparam.Add("backup_number", backup_number);
            vResultJson.Add("param", vjobjparam);
            string sFinal = vResultJson.ToString(Formatting.None);
            byte[] strParam = new byte[0];
            cmdTrans.CreateBSCommBufferFromString(sFinal, out strParam);
            mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "SET_COMMAND", mDevId, strParam);
            Enables(false);
        }
        catch (Exception ex)
        {
            StatusTxt.Text = ex.ToString();
        }
    }
    protected void ClearManagerBtn_Click(object sender, EventArgs e)
    {
        try
        {
            Session["operation"] = ALL_MANAGER_DEL;
            string sDevId = Device_List.SelectedItem.Value;

            if (sDevId != null)
            {
                Session["dev_id"] = sDevId;
                mDevId = (string)Session["dev_id"];
            }
            mTransIdTxt.Text = FKWebTools.MakeCmd(msqlConn, "CLEAR_MANAGER", mDevId, null);
            Enables(false);
        }
        catch (Exception ex)
        {
            StatusTxt.Text = ex.ToString();
        }
    }
}
