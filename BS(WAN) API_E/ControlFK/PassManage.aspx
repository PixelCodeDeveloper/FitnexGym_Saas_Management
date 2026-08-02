<%@ Page Language="C#" AutoEventWireup="true" CodeFile="PassManage.aspx.cs" Inherits="DeviceManage"
    ValidateRequest="false" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Untitled Page</title>
</head>
<body>
    <form id="form1" runat="server">
    <asp:ScriptManager ID="ScriptManager1" runat="server">
    </asp:ScriptManager>
    <div>
        <asp:UpdatePanel ID="UpdatePanel2" runat="server" UpdateMode="Always">
            <ContentTemplate>
                <div>
                    <div style="border: thin hidden #00FF00; font-size: xx-large; background-color: #C0C0C0;
                        height: 49px; margin-bottom: 17px;">
                        &nbsp;&nbsp; FKAttend BS Sample</div>
                </div>
                <asp:Panel ID="Panel1" runat="server" BackColor="#CCCCCC" Font-Size="Large" Height="28px"
                    Style="margin-bottom: 10px">
                    &nbsp;&nbsp;&nbsp;&nbsp; Pass Manage&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                    <asp:Label ID="Label1" runat="server" Text="Device ID :"></asp:Label>
                    &nbsp;&nbsp;
                    <asp:Label ID="DevID" runat="server"></asp:Label>
                    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                    <asp:LinkButton ID="goback" runat="server" OnClick="goback_Click">Go Home</asp:LinkButton>
                    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                </asp:Panel>
                <asp:TextBox ID="mTransIdTxt" runat="server" Visible="False"></asp:TextBox>
                <asp:Panel ID="PanelUserPassTime" runat="server" BackColor="#EEEEEE" Height="280px"
                    Style="margin-bottom: 20px; margin-top: 20px">
                    <br />
                    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                    <asp:Button ID="SetUserPassTimeBtn" runat="server" Text="Set_User_PassTime" 
                        onclick="SetUserPassTimeBtn_Click" />
                    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                    <asp:Button ID="GetUserPassTimeBtn" runat="server" Text="Get_User_PassTime" 
                        onclick="GetUserPassTimeBtn_Click" />
                    <br />
                    <br />
                    &nbsp; UserID:<asp:TextBox ID="UserIDTxt" runat="server" Style="margin-left: 100px"></asp:TextBox>
                    <br />
                    <br />
                    &nbsp; Valide Date start:<asp:TextBox ID="ValideDateStartTxt" runat="server" Style="margin-left: 13px;
                        margin-right: 110px;" placeholder="yyyyMMdd"></asp:TextBox>
                    Valide Date end:<asp:TextBox ID="ValideDateEndTxt" runat="server" Style="margin-left: 45px"  placeholder="yyyyMMdd"></asp:TextBox>
                    <br />
                    <br />
                    &nbsp; Week TimeZone No:<br />
                    <br />
                    &nbsp;&nbsp; Sun:<asp:TextBox ID="SunTxt" runat="server" Style="margin-right: 20px" placeholder="1-255"></asp:TextBox>
                    Mon:<asp:TextBox ID="MonTxt" runat="server" Style="margin-right: 20px" placeholder="1-255"></asp:TextBox>
                    Tue:<asp:TextBox ID="TueTxt" runat="server" Style="margin-right: 20px" placeholder="1-255"></asp:TextBox>
                    Wed:<asp:TextBox ID="WebTxt" runat="server" Style="margin-right: 20px" placeholder="1-255"></asp:TextBox>
                    <br />
                    <br />
                    &nbsp;&nbsp; Thu:<asp:TextBox ID="ThuTxt" runat="server" Style="margin-right: 20px" placeholder="1-255"></asp:TextBox>
                    Fri:<asp:TextBox ID="FriTxt" runat="server" Style="margin-right: 20px" placeholder="1-255"></asp:TextBox>
                    Sat:<asp:TextBox ID="SatTxt" runat="server" Style="margin-right: 20px" placeholder="1-255"></asp:TextBox>
                </asp:Panel>
                <asp:Panel ID="PanelTimeZoneNo" runat="server" BackColor="#EEEEEE" Height="280px"
                    Style="margin-bottom: 20px; margin-top: 20px">
                    <br />
                    <span style="margin-left: 20px">TimeZone No.</span><asp:TextBox ID="TimeZoneNoTxt" runat="server" Style="margin-left: 30px" placeholder="1-255" onkeypress="if (event.keyCode<48 || event.keyCode>57) event.returnValue=false;"></asp:TextBox>
                    <asp:Button ID="SetTimeZoneBtn" runat="server" Text="Set_TimeZone" 
                        Style="margin-left: 200px" onclick="SetTimeZoneBtn_Click" />
                    <asp:Button ID="GetTimeZoneBtn" runat="server" Text="Get_TimeZone" 
                        Style="margin-left: 200px" onclick="GetTimeZoneBtn_Click" />
                    <br />
                    <br />
                    <span style="margin-left: 200px">start</span><span style="margin-left: 320px">end</span><br />
                    <span style="margin-left: 50px">T1</span><asp:TextBox ID="T1StartTxt" runat="server" Style="margin-right: 200px; margin-left: 80px;
                        margin-top: 10px;" placeholder="HHmm"></asp:TextBox>
                    <asp:TextBox ID="T1EndTxt" runat="server" placeholder="HHmm"></asp:TextBox><br />
                    <span style="margin-left: 50px">T2</span><asp:TextBox ID="T2StartTxt" runat="server" Style="margin-right: 200px; margin-left: 80px;
                        margin-top: 10px;" placeholder="HHmm"></asp:TextBox>
                    <asp:TextBox ID="T2EndTxt" runat="server" placeholder="HHmm"></asp:TextBox><br />
                    <span style="margin-left: 50px">T3</span><asp:TextBox ID="T3StartTxt" runat="server" Style="margin-right: 200px; margin-left: 80px;
                        margin-top: 10px;" placeholder="HHmm"></asp:TextBox>
                    <asp:TextBox ID="T3EndTxt" runat="server" placeholder="HHmm"></asp:TextBox><br />
                    <span style="margin-left: 50px">T4</span><asp:TextBox ID="T4StartTxt" runat="server" Style="margin-right: 200px; margin-left: 80px;
                        margin-top: 10px;" placeholder="HHmm"></asp:TextBox>
                    <asp:TextBox ID="T4EndTxt" runat="server" placeholder="HHmm"></asp:TextBox><br />
                    <span style="margin-left: 50px">T5</span><asp:TextBox ID="T5StartTxt" runat="server" Style="margin-right: 200px; margin-left: 80px;
                        margin-top: 10px;" placeholder="HHmm"></asp:TextBox>
                    <asp:TextBox ID="T5EndTxt" runat="server" placeholder="HHmm"></asp:TextBox><br />
                    <span style="margin-left: 50px">T6</span><asp:TextBox ID="T6StartTxt" runat="server" Style="margin-right: 200px; margin-left: 80px;
                        margin-top: 10px;" placeholder="HHmm"></asp:TextBox>
                    <asp:TextBox ID="T6EndTxt" runat="server" placeholder="HHmm"></asp:TextBox><br />
                </asp:Panel>
                <asp:Panel ID="PanelDeviceSetting" runat="server" BackColor="#EEEEEE" Height="200px"
                    Style="margin-bottom: 20px; margin-top: 20px">
                    <br />
                    <asp:Button ID="SetDeviceSettingBtn" runat="server" Style="margin-left: 200px" 
                        Text="Set_Device_Setting" onclick="SetDeviceSettingBtn_Click" />
                    <asp:Button ID="GetDeviceSettingBtn" runat="server" Style="margin-left: 200px" 
                        Text="Get_Device_Setting" onclick="GetDeviceSettingBtn_Click" />
                    <br />
                    <span style="margin-left: 50px">OpenDoorDelay</span><asp:TextBox ID="OpenDoorDelayTxt" runat="server"
                        placeholder="second" Style="margin-left: 30px; margin-top: 10px" onkeypress="if (event.keyCode<48 || event.keyCode>57) event.returnValue=false;"></asp:TextBox>
                    <span style="margin-left: 50px">DoorMagneticDelay</span><asp:TextBox ID="DoorMagneticDelayTxt" runat="server"
                        placeholder="second" Style="margin-left: 30px; margin-top: 10px" onkeypress="if (event.keyCode<48 || event.keyCode>57) event.returnValue=false;"></asp:TextBox>
                    <span style="margin-left: 50px">AlarmDelay</span><asp:TextBox ID="AlarmDelayTxt" runat="server"
                        placeholder="second" Style="margin-left: 30px; margin-top: 10px" onkeypress="if (event.keyCode<48 || event.keyCode>57) event.returnValue=false;"></asp:TextBox><br />
                    <span style="margin-left: 50px">SleepTime</span><asp:TextBox ID="SleepTimeTxt" runat="server"
                        placeholder="minute" Style="margin-left: 62px; margin-top: 10px" onkeypress="if (event.keyCode<48 || event.keyCode>57) event.returnValue=false;"></asp:TextBox>
                    <span style="margin-left: 50px">ScreensaversTime</span><asp:TextBox ID="ScreensaversTimeTxt" runat="server"
                        placeholder="minute" Style="margin-left: 38px; margin-top: 10px" onkeypress="if (event.keyCode<48 || event.keyCode>57) event.returnValue=false;"></asp:TextBox>
                    <span style="margin-left: 50px">ReverifyTime</span><asp:TextBox ID="ReverifyTimeTxt" runat="server"
                        placeholder="minute" Style="margin-left: 14px; margin-top: 10px" onkeypress="if (event.keyCode<48 || event.keyCode>57) event.returnValue=false;"></asp:TextBox><br />
                    <span style="margin-left: 50px">DoorMagneticType</span><asp:DropDownList ID="DoorMagneticTypeSelect"
                        runat="server" Style="margin-left: 6px; margin-top: 10px" Width="148px">
                        <asp:ListItem Selected="True">no</asp:ListItem>
                        <asp:ListItem>open</asp:ListItem>
                        <asp:ListItem>close</asp:ListItem>
                    </asp:DropDownList>
                    <span style="margin-left: 50px">Anti-back</span><asp:DropDownList ID="AntibackSelect"
                        runat="server" Style="margin-left: 94px; margin-top: 10px" Width="148px">
                        <asp:ListItem>yes</asp:ListItem>
                        <asp:ListItem Selected="True">no</asp:ListItem>
                    </asp:DropDownList>
                    <span style="margin-left: 50px">UseAlarm</span><asp:DropDownList ID="UseAlarmSelect"
                        runat="server" Style="margin-left: 46px; margin-top: 10px" Width="148px">
                        <asp:ListItem Selected="True">yes</asp:ListItem>
                        <asp:ListItem>no</asp:ListItem>
                    </asp:DropDownList>
                    <br />
                    <span style="margin-left: 50px">WiegandType</span><asp:DropDownList ID="WiegandTypeSelect"
                        runat="server" Style="margin-left: 46px; margin-top: 10px" Width="148px">
                        <asp:ListItem Selected="True">26</asp:ListItem>
                        <asp:ListItem>34</asp:ListItem>
                    </asp:DropDownList>
                    <span style="margin-left: 50px">GlogWarning</span><asp:TextBox ID="GlogWarningTxt" runat="server"
                        placeholder="1-1000" Style="margin-left: 78px; margin-top: 10px" onkeypress="if (event.keyCode<48 || event.keyCode>57) event.returnValue=false;"></asp:TextBox>
                    <span style="margin-left: 50px">Volume</span><asp:TextBox ID="VolumeTxt" runat="server"
                        placeholder="0-10" Style="margin-left: 62px; margin-top: 10px" onkeypress="if (event.keyCode<48 || event.keyCode>57) event.returnValue=false;"></asp:TextBox>
                </asp:Panel>
                <asp:TextBox ID="debugTxt" runat="server" Visible="False"></asp:TextBox>
                <br />
                <asp:Panel ID="PanelOpenDoot" runat="server" BackColor="#CC0000" Height="50px"
                    Style="margin-bottom: 20px; margin-top: 20px">
                    <asp:Button ID="SetDoorStatusBtn" runat="server" Text="SetDoorStatus" 
                        Style="margin-left: 200px; margin-top: 20px" onclick="SetDoorStatusBtn_Click"/>
                        <asp:DropDownList ID="SetDoorStatusSelect"
                        runat="server" Style="margin-left: 100px; margin-top: 20px">
                        <asp:ListItem Selected="True">open</asp:ListItem>
                        <asp:ListItem>close</asp:ListItem>
                    </asp:DropDownList>
                    <span style="margin-left: 50px; margin-bottom: 20px; color:#FFFF00; font-size:large ;font-style:oblique">Not encrypted!!! Use with caution!!!</span>
                </asp:Panel>
                <br />
                <br />
                <asp:Panel ID="Panel5" runat="server" BorderStyle="Groove" Height="44px" Style="margin-top: 11px"
                    BackColor="#EEEEEE">
                    &nbsp;
                    <asp:Label ID="Label9" runat="server" Font-Size="Large" Text="Status"></asp:Label>
                    <br />
                    &nbsp; &nbsp;&nbsp;&nbsp;
                    <asp:Label ID="StatusTxt" runat="server"></asp:Label>
                </asp:Panel>
                <asp:Timer ID="Timer" runat="server" Interval="10" OnTick="Timer_Watch" Enabled="False">
                </asp:Timer>
            </ContentTemplate>
        </asp:UpdatePanel>
    </form>
</body>
</html>
