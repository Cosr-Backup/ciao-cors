import { useState } from 'react';
import { Container, Paper, TextInput, PasswordInput, Button, Title, Group, Alert } from '@mantine/core';
import { useForm } from '@mantine/form';
import { IconAlertCircle } from '@tabler/icons-react';
import { useAuth } from '../contexts/AuthContext';

interface LoginPageProps {
  onLogin: () => void;
}

export default function LoginPage({ onLogin }: LoginPageProps) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { login } = useAuth();

  const form = useForm({
    initialValues: {
      username: '',
      password: '',
    },
    validate: {
      username: (value) => (value.length < 1 ? '请输入用户名' : null),
      password: (value) => (value.length < 1 ? '请输入密码' : null),
    },
  });

  const handleSubmit = async (values: typeof form.values) => {
    setLoading(true);
    setError(null);

    try {
      const success = await login(values.username, values.password);
      if (success) {
        onLogin();
      } else {
        setError('用户名或密码错误');
      }
    } catch (err) {
      setError('登录失败，请稍后重试');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Container size={420} my={40}>
      <Title ta="center" mb="xl">
        Ciao-CORS 管理后台
      </Title>

      <Paper withBorder shadow="md" p={30} radius="md">
        <form onSubmit={form.onSubmit(handleSubmit)}>
          <TextInput
            label="用户名"
            placeholder="admin"
            required
            {...form.getInputProps('username')}
          />

          <PasswordInput
            label="密码"
            placeholder="请输入密码"
            required
            mt="md"
            {...form.getInputProps('password')}
          />

          {error && (
            <Alert icon={<IconAlertCircle size={16} />} color="red" mt="md">
              {error}
            </Alert>
          )}

          <Group justify="space-between" mt="lg">
            <Button type="submit" fullWidth loading={loading}>
              登录
            </Button>
          </Group>
        </form>
      </Paper>
    </Container>
  );
}