import { useState } from "react";
import { globalCSS } from "./styles.js";

// Componentes estructurales
import Sidebar from "./components/Sidebar.jsx";

// Páginas (una por pantalla del mockup)
import Login           from "./pages/Login.jsx";
import Dashboard       from "./pages/Dashboard.jsx";
import AdminDashboard  from "./pages/AdminDashboard.jsx";
import UploadCSV       from "./pages/UploadCSV.jsx";
import JobStatus       from "./pages/JobStatus.jsx";
import History         from "./pages/History.jsx";
import ReportDetail    from "./pages/ReportDetail.jsx";
import SellerDashboard from "./pages/SellerDashboard.jsx";
import ErrorLog        from "./pages/ErrorLog.jsx";

// Página inicial por rol
const DEFAULT_PAGE = {
  analista:      "dashboard",
  gerente:       "history",
  vendedor:      "seller",
  administrador: "dashboard",
  auditor:       "history",
};

export default function App() {
  const [user, setUser] = useState(() => {
    try { return JSON.parse(localStorage.getItem("spvr_user")); }
    catch { return null; }
  });

  const [page, setPage]                 = useState("dashboard");
  const [selectedJob, setSelectedJob]   = useState(null); // para JobStatus
  const [selectedReport, setSelectedReport] = useState(null); // para ReportDetail

  const handleLogin = (u) => {
    setUser(u);
    setPage(DEFAULT_PAGE[u.rol] || "dashboard");
  };

  const handleLogout = () => {
    localStorage.removeItem("spvr_user");
    localStorage.removeItem("spvr_token");
    setUser(null);
    setPage("dashboard");
  };

  if (!user) {
    return (
      <>
        <style>{globalCSS}</style>
        <Login onLogin={handleLogin} />
      </>
    );
  }

  const renderPage = () => {
    switch (page) {
      case "dashboard":
        // El administrador ve su propio dashboard, el analista el suyo
        if (user.rol === "administrador") {
          return <AdminDashboard setPage={setPage} />;
        }
        return <Dashboard user={user} setPage={setPage} setSelectedJob={setSelectedJob} setSelectedReport={setSelectedReport} />;
      case "upload":
        return <UploadCSV user={user} setPage={setPage} setSelectedJob={setSelectedJob} />;
      case "status":
        return <JobStatus job={selectedJob} />;
      case "history":
        return <History user={user} setPage={setPage} setSelectedReport={setSelectedReport} />;
      case "report":
        return <ReportDetail report={selectedReport} setPage={setPage} />;
      case "seller":
        return <SellerDashboard user={user} />;
      case "errors":
        return <ErrorLog />;
      default:
        if (user.rol === "administrador") {
          return <AdminDashboard setPage={setPage} />;
        }
        return <Dashboard user={user} setPage={setPage} setSelectedJob={setSelectedJob} setSelectedReport={setSelectedReport} />;
    }
  };

  return (
    <>
      <style>{globalCSS}</style>
      <div style={{ display: "flex", minHeight: "100vh" }}>
        <Sidebar user={user} page={page} setPage={setPage} onLogout={handleLogout} />
        <main style={{ marginLeft: 220, flex: 1, padding: "32px 36px", minHeight: "100vh" }}>
          {renderPage()}
        </main>
      </div>
    </>
  );
}
