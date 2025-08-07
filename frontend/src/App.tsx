import { Routes, Route } from 'react-router-dom';
import { AppShell, Burger, Group, Title } from '@mantine/core';
import { useDisclosure } from '@mantine/hooks';
import { useState } from 'react';
import Navbar from './components/Navbar';
import HomePage from './pages/HomePage';
import DashboardPage from './pages/DashboardPage';
import LoginPage from './pages/LoginPage';
import SettingsPage from './pages/SettingsPage';
import ApiKeysPage from './pages/ApiKeysPage';
import LogsPage from './pages/LogsPage';
import { AuthProvider } from './contexts/AuthContext';

function App() {
  const [mobileOpened, { toggle: toggleMobile }] = useDisclosure();
  const [desktopOpened, { toggle: toggleDesktop }] = useDisclosure(true);
  const [isLoggedIn, setIsLoggedIn] = useState(false);

  return (
    <AuthProvider>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/login" element={<LoginPage onLogin={() => setIsLoggedIn(true)} />} />
        <Route
          path="/dashboard/*"
          element={
            isLoggedIn ? (
              <AppShell
                header={{ height: 60 }}
                navbar={{
                  width: 300,
                  breakpoint: 'sm',
                  collapsed: { mobile: !mobileOpened, desktop: !desktopOpened },
                }}
                padding="md"
              >
                <AppShell.Header>
                  <Group h="100%" px="md">
                    <Burger opened={mobileOpened} onClick={toggleMobile} hiddenFrom="sm" size="sm" />
                    <Burger opened={desktopOpened} onClick={toggleDesktop} visibleFrom="sm" size="sm" />
                    <Title order={3}>Ciao-CORS 管理后台</Title>
                  </Group>
                </AppShell.Header>
                <AppShell.Navbar p="md">
                  <Navbar />
                </AppShell.Navbar>
                <AppShell.Main>
                  <Routes>
                    <Route path="/" element={<DashboardPage />} />
                    <Route path="/settings" element={<SettingsPage />} />
                    <Route path="/api-keys" element={<ApiKeysPage />} />
                    <Route path="/logs" element={<LogsPage />} />
                  </Routes>
                </AppShell.Main>
              </AppShell>
            ) : (
              <LoginPage onLogin={() => setIsLoggedIn(true)} />
            )
          }
        />
      </Routes>
    </AuthProvider>
  );
}

export default App;